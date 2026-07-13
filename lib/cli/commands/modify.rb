# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'open3'
require 'tty-prompt'
require 'tty-spinner'
require 'shellwords'
require 'diffy'

require_relative '../../services/validators/slurm_script_validator'
require_relative '../../services/module_extractor/module_extractor'
require_relative '../../services/prepare/prepare'
require_relative '../../services/local_scratch/local_scratch'
require_relative '../../services/editor/edit'

# Load subcommand
require_relative 'modify/remove'

module AlcesJob
  module CLI
    module Commands
      class Modify < Dry::CLI::Command
        AlcesJob::CLI.register 'modify', self
        desc 'This will modify a users script based on flags'

        argument :script, required: true, desc: 'The script to modify'

        option :job_name, type: :string, aliases: ['-J'], desc: 'Set the job name shown in Slurm'
        option :nodes, aliases: ['-N'], type: :integer, desc: 'Requests the number of compute nodes'
        option :ntasks, aliases: ['-n'], type: :integer, desc: 'Specifies the total number of tasks'
        option :cpus_per_task, aliases: ['-c'], type: :integer, desc: 'Specifies CPU cores per task'
        option :mem, type: :string, desc: 'Request memory for the job (for example: 4G or 2000M)'
        option :time, type: :string, aliases: ['-t'], desc: 'Set the maximum runtime for the job e.g. 02:00:00 or 1-00:00:00'
        option :partition, type: :string, aliases: ['-p'], desc: 'Choose which Slurm partition (queue) to run on'
        option :command, type: :string, desc: 'Command to run in the job script'
        option :account, type: :string, aliases: ['-A'], desc: 'Charge the job to the specified Slurm account'
        option :gres, type: :string, desc: 'Specifies generic resources such as GPUs, e.g. gpu:1'
        option :output, type: :string, desc: 'Write standard output to this file'
        option :error, type: :string, aliases: ['-e'], desc: 'Write standard error to this file'
        option :mail_user, type: :string, desc: 'Email address for job notifications'
        option :mail_type, type: :string, desc: 'When to send email notifications (for example: BEGIN, END, or FAIL)'
        option :array, type: :string, desc: 'Sets a Slurm array task specification'
        option :dependency, type: :string, desc: 'Sets a Slurm dependency string'
        option :module, type: :array, aliases: ['-m'], default: [], desc: 'Load one or more environment modules before running the job'
        option :workdir, type: :string, desc: 'Run the job from the specified working directory'
        option :output_file, aliases: ['-o'], type: :string, desc: 'Writes the modified script to this output filename'
        option :submit, type: :boolean, default: false, desc: 'Submit the generated job script to Slurm automatically'
        option :prepare, type: :boolean, default: false, desc: 'Prepare - CHANGE THIS'
        option :prepare_disable, type: :boolean, default: false, desc: 'Unprepare - CHANGEE THIS'
        option :local_scratch, type: :boolean, default: false, desc: 'Enable local scratch setup'
        option :local_scratch_disable, type: :boolean, default: false, desc: 'Disable local scratch setup'
        option :scratch_path, type: :string, desc: 'Set the local scratch base path'
        option :yes, type: :boolean, default: false, desc: 'Skip the confirmation prompt when submitting'

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
            '-e' => :error
          }.freeze
        end

        def call(script:, **options)
          options[:module] = AlcesJob::Services.module_extractor(ARGV)
          script = File.expand_path(script, Dir.pwd)
          pastel = Pastel.new
          prompt = TTY::Prompt.new

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

          edited_sbatch = []

          lines.each do |line|
            if line.start_with?('#!')
              edited_sbatch << line
              edited_sbatch << ''
            elsif line.start_with?('#SBATCH')
              match = line.match(/\A#SBATCH\s+(?<option>\S+)(?:\s+(?<spaced_value>.*))?\z/)

              unless match
                edited_sbatch << line
                next
              end

              option = match[:option]
              spaced_value = match[:spaced_value]
              inline_comment = line[/\s+(#.*)\z/, 1]

              next if options[:prepare] && line.match?(/\A#SBATCH\s+--(?:output|error)(?:=|\s+)/)

              option_key = nil

              if option.include?('=')
                name, raw_value = option.split('=', 2)
                long_name = name.delete_prefix('--')

                option_key = @sbatch_options.find do |_key, sbatch_name|
                  sbatch_name == long_name
                end&.first

                raw_value.to_s.sub(/\s+#.*\z/, '').strip

              elsif option.start_with?('--')
                long_name = option.delete_prefix('--')

                option_key = @sbatch_options.find do |_key, sbatch_name|
                  sbatch_name == long_name
                end&.first

                spaced_value.to_s.sub(/\s+#.*\z/, '').strip

              else
                short_name = option[0, 2]
                option_key = @short_options[short_name]

                compact_value = option.length > 2 ? option[2..] : nil
                (compact_value || spaced_value).to_s.sub(/\s+#.*\z/, '').strip
              end

              next if options[:prepare] && %i[output error].include?(option_key)

              unless option_key
                edited_sbatch << line
                next
              end

              found_options << option_key

              if options.key?(option_key) &&
                 !options[option_key].nil? &&
                 options[option_key] != false &&
                 !(options[option_key].respond_to?(:empty?) && options[option_key].empty?)

                new_value = options[option_key]
                directive = "#SBATCH --#{@sbatch_options.fetch(option_key)}=#{new_value}"

              else
                edited_sbatch << line
                next

              end
              edited_sbatch << format_directive(directive, inline_comment)

            end
          end

          options.each do |key, value|
            next if found_options.include?(key)
            next unless @sbatch_options.key?(key)
            next if value.nil? || value == false
            next if value.respond_to?(:empty?) && value.empty?

            sbatch_name = @sbatch_options[key]
            edited_sbatch << "#SBATCH --#{sbatch_name}=#{value}"
          end

          job_name = options[:job_name] || find_existing_job_name(lines) || 'slurm_job'
          edited_script << ''

          # Find exisitng prepare lines
          prepare_lines = []
          inside_prepare = false

          lines.each do |line|
            stripped = line.strip

            inside_prepare = true if stripped == 'alces_prepare_job() {'

            prepare_lines << line if inside_prepare

            if inside_prepare && stripped == 'alces_prepare_job'
              inside_prepare = false
              break
            end
          end

          existing_prepare = prepare_lines.any?

          # Find existing local scratch lines
          local_scratch_lines = []
          inside_local_scratch = false

          lines.each do |line|
            stripped = line.strip

            inside_local_scratch = true if stripped == 'alces_setup_local_scratch() {'

            local_scratch_lines << line if inside_local_scratch

            if inside_local_scratch && stripped == 'trap alces_copy_results_back EXIT'
              inside_local_scratch = false
              break
            end
          end

          existing_local_scratch = local_scratch_lines.any?
          managed_setup_lines = prepare_lines + local_scratch_lines

          existing_cd_line = lines.find { |line| line.strip.start_with?('cd ') && !managed_setup_lines.include?(line) }
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

          edited_script << 'module purge' if modules_to_write.any?

          modules_to_write.each do |m|
            m = m.to_s.strip
            next if m.empty?
            next if used_modules.include?(m)

            edited_script << "module load #{m}"
            used_modules << m
          end

          if options[:prepare]
            edited_script << ''
            prepare_directives = Services::Prepare.directives.lines(chomp: true).reject do |line|
              (options[:output] && line.start_with?('#SBATCH --output')) ||
                (options[:error] && line.start_with?('#SBATCH --error'))
            end
            prepare_directives.each do |line|
              edited_sbatch << line
            end
            edited_script << Services::Prepare.helper
          elsif options[:prepare_disable] && existing_prepare
            edited_script << ''
          elsif existing_prepare
            edited_script << ''
            prepare_lines.each do |line|
              edited_script << line
            end
          end

          if options[:local_scratch]
            edited_script << ''
            Services::LocalScratch.helper(scratch_path: options[:scratch_path]).lines(chomp: true).each do |line|
              edited_script << line
            end
          elsif options[:local_scratch_disable] && existing_local_scratch
            edited_script << ''
          elsif existing_local_scratch
            edited_script << ''
            local_scratch_lines.each do |line|
              edited_script << line
            end
          end

          job_name = job_name.split.first if job_name

          edited_script << ''
          edited_script << %(echo "Running job '#{job_name}'") if job_name
          edited_script << ''

          if options[:command]
            lines.each do |line|
              next unless line.strip.start_with?('#')
              next if line.start_with?('#!', '#SBATCH')
              next if managed_setup_lines.include?(line)

              edited_script << line
            end
            edited_script << options[:command]
          else
            lines.each do |line|
              next if line.start_with?('#!')
              next if line.start_with?('#SBATCH')
              next if managed_setup_lines.include?(line)
              next if line.strip == 'module purge'
              next if line.strip.start_with?('module load ')
              next if line.strip.start_with?('cd ')
              next if line.strip.match?(/\Aecho\s+["']Running job\b/)
              next if line.empty? && edited_script.last == ''

              edited_script << line
            end
          end

          spinner.success(pastel.green('(Successful)'))

          edited_script = edited_sbatch + edited_script

          # ------------------------------------------------------------
          # Display changes
          # ------------------------------------------------------------
          puts

          modified_content = "#{edited_script.join("\n")}\n"

          AlcesJob::Services::Editor.show_edited_script_preview(old_content, modified_content, pastel)

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
              unless options[:yes] || prompt.yes?('Submit this job to Slurm?', default: false)
                puts pastel.yellow("\nSubmission skipped.\n")
                exit(0)
              end

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

        def highlighted_scripts(old_content, modified_content, pastel)
          diff = Diffy::Diff.new(
            remove_empty_lines(old_content),
            remove_empty_lines(modified_content),
            context: 0
          ).to_s

          removed_lines = []
          added_lines = []

          diff.lines.each do |line|
            if line.start_with?('-') && !line.start_with?('---')
              removed_lines << line[1..].chomp
            elsif line.start_with?('+') && !line.start_with?('+++')
              added_lines << line[1..].chomp
            end
          end

          highlighted_old = old_content.lines.map do |line|
            clean_line = line.chomp

            if removed_lines.include?(clean_line)
              "#{pastel.red(line.chomp)}\n"
            else
              line
            end
          end.join

          highlighted_new = modified_content.lines.map do |line|
            clean_line = line.chomp

            if added_lines.include?(clean_line)
              "#{pastel.green(line.chomp)}\n"
            else
              line
            end
          end.join

          [highlighted_old, highlighted_new]
        end

        def remove_empty_lines(content)
          content.lines.reject { |line| line.strip.empty? }.join
        end

        # Finds the existing job nma in the file
        # @param [Array<String>] lines
        # @return [String]
        def find_existing_job_name(lines)
          job_line = lines.find { |line| line.start_with?('#SBATCH --job-name=') }
          return nil unless job_line

          job_line.split('=', 2).last
        end

        # Align an inherited directive comment with the generated templates.
        def format_directive(directive, inline_comment)
          return directive unless inline_comment

          return "#{directive.ljust(50)}#{inline_comment}" if directive.length < 50

          "#{directive} #{inline_comment}"
        end
      end
    end
  end
end
