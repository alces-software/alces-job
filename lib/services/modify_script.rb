# frozen_string_literal: true

require_relative 'slurm_script_validator'
require 'open3'

module AlcesJob
  module Services
    class ModifyScript
      def initialize(script:, options:)
        @sbatch_options = {
          job_name: 'job-name',
          nodes: 'nodes',
          ntasks: 'ntasks',
          cpus_per_task: 'cpus-per-task',
          mem: 'mem',
          time: 'time',
          partition: 'partition',
          account: 'account',
          gres: 'gres',
          output: 'output',
          error: 'error',
          mail_user: 'mail-user',
          mail_type: 'mail-type',
          array: 'array',
          dependency: 'dependency'
        }.freeze

        @script = File.expand_path(script, Dir.pwd)
        @options = options
        return unless @options[:args]&.any?

        warn "ERROR: Unexpected arguments: #{@options[:args].join(' ')}"
        warn 'Wrap the command in quotes, e.g. --command="python script.py"'
        exit 1
      end

      def find_existing_job_name(lines)
        job_line = lines.find { |line| line.start_with?('#SBATCH --job-name=') }
        return nil unless job_line

        job_line.split('=', 2).last
      end

      def call
        unless File.exist?(@script)
          puts "Script not found: #{@script}"
          return
        end

        old_content = File.read(@script)

        lines = File.readlines(@script, chomp: true)

        edited_script = []

        found_options = []

        lines.each do |line|
          if line.start_with?('#!')
            edited_script << line

          elsif line.start_with?('#SBATCH')
            parts = line.split[1]

            unless parts&.start_with?('--') && parts.include?('=')
              edited_script << line
              next
            end

            name, _old_value = parts.split('=', 2)

            option_key = name.tr('-', '_').delete_prefix('__').to_sym
            found_options << option_key

            if @options.key?(option_key) && !@options[option_key].nil?
              new_value = @options[option_key]
              edited_script << "#SBATCH #{name}=#{new_value}"

            else
              edited_script << line
            end
          end
        end

        @options.each do |key, value|
          next if found_options.include?(key)
          next unless @sbatch_options.key?(key)
          next if value.nil?
          next if value == false
          next if value.respond_to?(:empty?) && value.empty?

          sbatch_name = @sbatch_options[key]
          edited_script << "#SBATCH --#{sbatch_name}=#{value}"
        end

        job_name = @options[:job_name] || find_existing_job_name(lines) || 'slurm_job'
        edited_script << ''

        existing_cd_line = lines.find { |line| line.strip.start_with?('cd ') }
        existing_modules = lines.select { |line| line.strip.start_with?('module load ') }.map { |line| line.strip.sub(/^module load\s+/, '') }

        if @options[:workdir] && !@options[:workdir].to_s.empty?
          edited_script << "cd #{@options[:workdir]}\n"
        elsif existing_cd_line
          edited_script << "#{existing_cd_line}\n"
        end

        modules_to_write =
          if @options[:module]&.any?
            @options[:module]
          else
            existing_modules
          end

        used_modules = []

        modules_to_write.each do |m|
          m = m.to_s.strip
          next if m.empty?
          next if used_modules.include?(m)

          edited_script << "module load #{m}"
          used_modules << m
        end

        edited_script << ''
        edited_script << %(echo "Running job '#{job_name}'") if job_name
        edited_script << ''

        if @options[:command]

          edited_script << @options[:command]
        else
          lines.each do |line|
            next if line.start_with?('#!')
            next if line.start_with?('#SBATCH')
            next if line.strip.start_with?('module load ')
            next if line.strip.start_with?('cd ')
            next if line.strip.start_with?('echo "Running job ')
            next if line.empty? && edited_script.last == ''

            edited_script << line
          end
        end

        puts edited_script.join("\n")

        file_path = if @options[:output_file]
                      File.join(Dir.pwd, @options[:output_file])
                    else
                      @script
                    end

        File.write(file_path, "#{edited_script.join("\n")}\n")

        validator = SlurmScriptValidator.new(file_path)

        if validator.validate?

          if @options[:submit] == true
            stdout, _, status = Open3.capture3("sbatch #{file_path}")

            puts 'sbatch finished.'
            puts "Exit status: #{status.exitstatus}"

            unless stdout.empty?
              puts 'STDOUT:'
              puts stdout
            end

            [stdout, status]

          end

          puts 'Script updated successfully.'

        else
          File.write(file_path, old_content)

          puts 'Changes were invalid, so the script was reverted.'

          validator.errors.each do |error|
            puts "ERROR: #{error}"
          end

        end
        validator.warnings.each do |warning|
          puts "WARNING: #{warning}"
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    end
  end
end
