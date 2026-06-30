# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'open3'
require 'tty-prompt'
require 'tty-spinner'
require 'shellwords'

require_relative '../../services/validators/slurm_script_validator'
require_relative '../../services/module_extractor/module_extractor'

# Load subcommand
require_relative 'modify/remove'

module AlcesJob
  module CLI
    module Commands
      class Modify < Dry::CLI::Command
        AlcesJob::CLI.register 'modify', self
        desc 'This will modify a users script based on flags'

        argument :script, required: true, desc: 'The script to modify'

        option :job_name, aliases: ['-j'], type: :string, desc: 'Sets the Slurm job name'
        option :nodes, aliases: ['-N'], type: :integer, desc: 'Requests the number of compute nodes'
        option :ntasks, aliases: ['-n'], type: :integer, desc: 'Specifies the total number of tasks'
        option :cpus_per_task, aliases: ['-c'], type: :integer, desc: 'Specifies CPU cores per task'
        option :mem, type: :string, desc: 'Sets the memory requirement for the job, e.g. 4G or 2000M'
        option :time, aliases: ['-t'], type: :string, desc: 'Sets the job walltime limit, e.g. 02:00:00 or 1-00:00:00'
        option :partition, aliases: ['-p'], type: :string, desc: 'Specifies the Slurm partition or queue to use'
        option :account, aliases: ['-A'], type: :string, desc: 'Specifies the Slurm account to charge'
        option :gres, type: :string, desc: 'Specifies generic resources such as GPUs, e.g. gpu:1'
        option :output, type: :string, desc: 'Sets the Slurm stdout file path'
        option :error, aliases: ['-e'], type: :string, desc: 'Sets the Slurm stderr file path'
        option :mail_user, type: :string, desc: 'Sets the email address for Slurm notifications'
        option :mail_type, type: :string, desc: 'Sets the Slurm mail notification type, e.g. BEGIN, END, FAIL'
        option :array, type: :string, desc: 'Sets a Slurm array task specification'
        option :dependency, type: :string, desc: 'Sets a Slurm dependency string'
        option :module, aliases: ['-m'], type: :array, default: [], desc: 'Loads one or more environment modules before running the job'
        option :workdir, type: :string, desc: 'Changes to the specified working directory in the job script'
        option :command, type: :string, desc: 'Specifies the shell command to execute in the script'
        option :output_file, aliases: ['-o'], type: :string, desc: 'Writes the modified script to this output filename'
        option :submit, type: :boolean, default: false, desc: 'Submits the script to Slurm automatically'

        def initialize
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

          @short_options = {
            '-J' => :job_name,
            '-N' => :nodes,
            '-n' => :ntasks,
            '-c' => :cpus_per_task,
            '-t' => :time,
            '-p' => :partition,
            '-A' => :account,
            '-o' => :output,
            '-e' => :error
          }.freeze
        end

        def call(script:, **options)
          options[:module] = AlcesJob::Services.module_extractor(ARGV)
          script = File.expand_path(script, Dir.pwd)
          pastel = Pastel.new

          # ------------------------------------------------------------
          # Input validation
          # ------------------------------------------------------------
          if script.to_s.strip.empty?
            warn pastel.red("\nNo script path was provided.\n")
            exit(1)
          end

          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.update(title: 'checking script exists')
          spinner.auto_spin

          # ------------------------------------------------------------
          # Exist check
          # ------------------------------------------------------------
          begin
            unless File.exist?(script)
              spinner.error(pastel.red('(Unable to find)'))
              warn pastel.red("\nScript can't be found.\n")
              exit(1)
            end
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to find)'))
            warn pastel.red("\nFailed to check for script.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Script found)'))
          spinner.update(title: 'reading script')
          spinner.auto_spin

          # ------------------------------------------------------------
          # Read script
          # ------------------------------------------------------------
          begin
            old_content = File.read(script)
            lines = old_content.lines(chomp: true)
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to read)'))
            warn pastel.red("\nFailed to read file.")
            warn pastel.red("#{e.message}}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Successful)'))
          spinner.update(title: 'generating new script')
          spinner.auto_spin

          # ------------------------------------------------------------
          # Edit script
          # ------------------------------------------------------------
          edited_script = []
          found_options = []

          lines.each do |line|
            if line.start_with?('#!')
              edited_script << line
            elsif line.start_with?('#SBATCH')
              match = line.match(/\A#SBATCH\s+(?<option>\S+)(?:\s+(?<spaced_value>.*))?\z/)

              unless match
                edited_script << line
                next
              end

              option = match[:option]
              spaced_value = match[:spaced_value]

              option_key = nil
              value = nil

              if option.include?('=')
                name, raw_value = option.split('=', 2)
                long_name = name.delete_prefix('--')

                option_key = @sbatch_options.find do |_key, sbatch_name|
                  sbatch_name == long_name
                end&.first

                value = raw_value.to_s.sub(/\s+#.*\z/, '').strip

              elsif option.start_with?('--')
                long_name = option.delete_prefix('--')

                option_key = @sbatch_options.find do |_key, sbatch_name|
                  sbatch_name == long_name
                end&.first

                value = spaced_value.to_s.sub(/\s+#.*\z/, '').strip

              else
                short_name = option[0, 2]
                option_key = @short_options[short_name]

                compact_value = option.length > 2 ? option[2..] : nil
                value = (compact_value || spaced_value).to_s.sub(/\s+#.*\z/, '').strip
              end

              unless option_key
                edited_script << line
                next
              end

              found_options << option_key

              if options.key?(option_key) &&
                 !options[option_key].nil? &&
                 options[option_key] != false &&
                 !(options[option_key].respond_to?(:empty?) && options[option_key].empty?)

                new_value = options[option_key]
                edited_script << "#SBATCH --#{@sbatch_options.fetch(option_key)}=#{new_value}"
              else
                edited_script << "#SBATCH --#{@sbatch_options.fetch(option_key)}=#{value}"
              end

            end
          end

          options.each do |key, value|
            next if found_options.include?(key)
            next unless @sbatch_options.key?(key)
            next if value.nil? || value == false
            next if value.respond_to?(:empty?) && value.empty?

            sbatch_name = @sbatch_options[key]
            edited_script << "#SBATCH --#{sbatch_name}=#{value}"
          end

          job_name = options[:job_name] || find_existing_job_name(lines) || 'slurm_job'
          edited_script << ''

          existing_cd_line = lines.find { |line| line.strip.start_with?('cd ') }
          existing_modules = lines.select { |line| line.strip.start_with?('module load ') }.map { |line| line.strip.sub(/^module load\s+/, '') }

          if options[:workdir] && !options[:workdir].to_s.empty?
            edited_script << "cd #{Shellwords.escape(options[:workdir])}\n"
          elsif existing_cd_line
            edited_script << "#{existing_cd_line}\n"
          end

          modules_to_write =
            if options[:module]&.any?
              options[:module]
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

          if options[:command]

            edited_script << options[:command]
          else
            lines.each do |line|
              next if line.start_with?('#!')
              next if line.start_with?('#SBATCH')
              next if line.strip.start_with?('module load ')
              next if line.strip.start_with?('cd ')
              next if line.strip.start_with?('#')
              next if line.strip.start_with?('echo "Running job ')
              next if line.empty? && edited_script.last == ''

              edited_script << line
            end
          end

          spinner.success(pastel.green('(Successful)'))

          # ------------------------------------------------------------
          # Display changes
          # ------------------------------------------------------------
          puts
          box_width = old_content.lines.map { |line| line.chomp.length }.max + 4
          puts TTY::Box.frame(
            old_content,
            title: {
              top_center: pastel.bold.yellow(' ORIGINAL SCRIPT ')
            },
            padding: 1,
            border: :thick,
            width: box_width
          )

          puts
          modified_content = edited_script.join("\n")
          box_width = modified_content.lines.map { |line| line.chomp.length }.max + 4
          puts TTY::Box.frame(
            modified_content,
            title: {
              top_center: pastel.bold.green(' MODIFIED SCRIPT ')
            },
            padding: 1,
            border: :thick,
            width: box_width
          )

          unless TTY::Prompt.new.yes?("\nWould you like to save this script?", default: false)
            puts 'Aborting...'
            puts
            exit(0)
          end

          spinner.update(title: 'saving script')
          spinner.auto_spin

          # ------------------------------------------------------------
          # Save script
          # ------------------------------------------------------------
          file_path = if options[:output_file]
                        File.join(Dir.pwd, options[:output_file])
                      else
                        script
                      end

          begin
            File.write(file_path, "#{edited_script.join("\n")}\n")
          rescue Errno::ENOSPC
            spinner.error(pastel.red('(Disk full)'))
            warn pastel.red("\nCannot save script: disk is full.\n")
            exit(1)
          rescue Errno::ENOENT, Errno::ENOTDIR
            spinner.error(pastel.red('(Invalid path)'))
            warn pastel.red("\nCannot save script: output path is invalid or missing.\n")
            exit(1)
          rescue Errno::EACCES, Errno::EROFS
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red("\nCannot save script due to permissions or read-only filesystem.\n")
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Save failed)'))
            warn pastel.red("\nFailed to save SBATCH script.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Successful)'))
          spinner.update(title: 'validating script')
          spinner.auto_spin

          # ------------------------------------------------------------
          # Validate script
          # ------------------------------------------------------------
          begin
            validator = Services::SlurmScriptValidator.new(file_path)
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to validate)'))
            warn pastel.red('Failed to validate the script:')
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Finished validating)'))

          # ------------------------------------------------------------
          # Revert changes if validation fails
          # ------------------------------------------------------------
          if validator.validate?
            if options[:submit]
              begin
                stdout, stderr, status = Open3.capture3('sbatch', file_path)
                puts 'sbatch finished.'
                puts "Exit status: #{status.exitstatus}"
                unless stdout.empty?
                  puts 'STDOUT:'
                  puts stdout
                end
                unless stderr.empty?
                  puts pastel.red('STDERR:')
                  puts stderr
                end
              rescue StandardError => e
                warn pastel.red("\nFailed to submit job.")
                warn pastel.red("#{e.message}\n")
                exit(1)
              end
            end
            puts pastel.green("\nScript updated successfully.\n")
          else
            begin
              File.write(file_path, old_content)
            rescue Errno::ENOSPC
              spinner.error(pastel.red('(Disk full)'))
              warn pastel.red("\nCannot restore script: disk is full.\n")
              exit(1)
            rescue Errno::ENOENT, Errno::ENOTDIR
              spinner.error(pastel.red('(Invalid path)'))
              warn pastel.red("\nCannot restore script: output path is invalid or missing.\n")
              exit(1)
            rescue Errno::EACCES, Errno::EROFS
              spinner.error(pastel.red('(Permission denied)'))
              warn pastel.red("\nCannot restore script due to permissions or read-only filesystem.\n")
              exit(1)
            rescue StandardError => e
              spinner.error(pastel.red('(Restore failed)'))
              warn pastel.red("\nFailed to restore SBATCH script.")
              warn pastel.red("#{e.message}\n")
              exit(1)
            end

            puts pastel.red("\nChanges were invalid, so the script was reverted.\n")
            validator.errors.each do |error|
              puts "#{pastel.red('ERROR:')} #{error}"
            end

          end

          puts
          validator.warnings.each do |warning|
            puts "#{pastel.yellow('WARNING:')} #{warning}"
          end

          exit(0)

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          spinner&.error(pastel.red('(Unexpected error)'))
          warn pastel.red("\nAn unexpected error occurred while running the command.")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end

        private

        # Finds the existing job name in the file
        # @param [Array<String>] lines
        # @return [String]
        def find_existing_job_name(lines)
          job_line = lines.find { |line| line.start_with?('#SBATCH --job-name=') }
          return nil unless job_line

          job_line.split('=', 2).last
        end
      end
    end
  end
end
