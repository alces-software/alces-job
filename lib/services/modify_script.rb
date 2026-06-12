# frozen_string_literal: true

require_relative 'slurm_script_validator'

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

        puts found_options

        puts @options

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

        if @options[:command]
          puts 'hello'
          edited_script << ''
          edited_script << %(echo "Running job '#{job_name}'") if job_name
          edited_script << ''
          edited_script << @options[:command]
        else
          lines.each do |line|
            edited_script << line if !line.start_with?('#!') && !line.start_with?('#SBATCH')
          end
        end

        puts edited_script

        File.write(@script, edited_script.join("\n") + "\n")

        validator = SlurmScriptValidator.new(@script)

        if validator.validate?

          puts 'Script updated successfully.'

          validator.warnings.each do |warning|
            puts "WARNING: #{warning}"
          end
        else
          File.write(@script, old_content)

          puts 'Changes were invalid, so the script was reverted.'

          validator.errors.each do |error|
            puts "ERROR: #{error}"
          end

          validator.warnings.each do |warning|
            puts "WARNING: #{warning}"
          end
        end
      end
    end
  end
end
