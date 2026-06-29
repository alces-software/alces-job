# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'open3'
require 'tty-spinner'
require 'tty-prompt'

require_relative '../../../services/validators/slurm_script_validator'
require_relative '../../../services/module_extractor/module_extractor'

module AlcesJob
  module CLI
    module Commands
      class Remove < Dry::CLI::Command
        AlcesJob::CLI.register 'modify remove', self

        desc 'Remove SBATCH flags from a Slurm script'

        argument :script, required: true, desc: 'The script to modify'

        option :job_name, type: :boolean, aliases: ['-J'], default: false, desc: 'Remove job-name'
        option :nodes, type: :boolean, aliases: ['-N'], default: false, desc: 'Remove nodes'
        option :ntasks, type: :boolean, aliases: ['-n'], default: false, desc: 'Remove ntasks'
        option :cpus_per_task, type: :boolean, default: false, desc: 'Remove cpus-per-task'
        option :mem, type: :boolean, default: false, desc: 'Remove mem'
        option :time, type: :boolean, aliases: ['-t'], default: false, desc: 'Remove time'
        option :partition, type: :boolean, aliases: ['-p'], default: false, desc: 'Remove partition'
        option :account, type: :boolean, aliases: ['-A'], default: false, desc: 'Remove account'
        option :gres, type: :boolean, default: false, desc: 'Remove gres'
        option :output, type: :boolean, default: false, desc: 'Remove output'
        option :error, type: :boolean, aliases: ['-e'], default: false, desc: 'Remove error'
        option :mail_user, type: :boolean, default: false, desc: 'Remove mail-user'
        option :mail_type, type: :boolean, default: false, desc: 'Remove mail-type'
        option :array, type: :boolean, default: false, desc: 'Remove array'
        option :dependency, type: :boolean, default: false, desc: 'Remove dependency'
        option :output_file, aliases: ['-o'], type: :string, desc: 'Write to new file instead of overwriting'
        option :submit, type: :boolean, default: false, desc: 'Submit to Slurm after modification'

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
        end

        def call(script:, **options)
          pastel = Pastel.new
          TTY::Prompt.new

          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          script = File.expand_path(script, Dir.pwd)

          # ------------------------------------------------------------
          # Validate script exists
          # ------------------------------------------------------------
          unless File.exist?(script)
            warn pastel.red("\nScript not found: #{script}")
            warn pastel.yellow("Please check the file path and try again.\n")
            exit(1)
          end

          old_content = File.read(script)
          lines = old_content.lines(chomp: true)

          remove_keys = options.select { |_, v| v == true }.keys

          # ------------------------------------------------------------
          # Modify script
          # ------------------------------------------------------------
          spinner.update(title: 'processing SBATCH script')
          spinner.auto_spin

          edited_script = lines.each_with_object([]) do |line, result|
            if line.start_with?('#!')
              result << line
              next
            end

            if line.start_with?('#SBATCH')
              parts = line.split[1]

              unless parts&.start_with?('--') && parts.include?('=')
                result << line
                next
              end

              name, _value = parts.split('=', 2)
              key = name.sub('--', '').tr('-', '_').to_sym

              next if remove_keys.include?(key)

              result << line
              next
            end

            result << line
          end

          file_path =
            options[:output_file] ? File.join(Dir.pwd, options[:output_file]) : script

          # ------------------------------------------------------------
          # Save file
          # ------------------------------------------------------------
          begin
            File.write(file_path, "#{edited_script.join("\n")}\n")
          rescue Errno::ENOSPC
            spinner.error(pastel.red('(Disk full)'))
            warn pastel.red("\nThere is not enough disk space to save the file.\n")
            exit(1)
          rescue Errno::ENOENT, Errno::ENOTDIR
            spinner.error(pastel.red('(Invalid path)'))
            warn pastel.red("\nThe output location does not exist or is invalid.\n")
            exit(1)
          rescue Errno::EACCES, Errno::EROFS
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red("\nYou do not have permission to write to this location.\n")
            exit(1)
          rescue Errno::EISDIR
            spinner.error(pastel.red('(Invalid target)'))
            warn pastel.red("\nThe output path is a directory, not a file.\n")
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Write failed)'))
            warn pastel.red("\nFailed to write the modified script to disk:")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Updated)'))

          puts pastel.green("\nSBATCH script updated successfully.")
          puts pastel.green("Written to: #{file_path}\n")

          # ------------------------------------------------------------
          # Validate script
          # ------------------------------------------------------------
          begin
            validator = Services::SlurmScriptValidator.new(file_path)

            unless validator.validate?
              spinner.error(pastel.red('(Invalid script)'))

              warn pastel.red("\nThe modified script is invalid and has been reverted.\n")

              File.write(file_path, old_content)

              validator.errors.each do |error|
                warn pastel.red("Error: #{error}")
              end

              validator.warnings.each do |warning|
                warn pastel.yellow("Warning: #{warning}")
              end

              exit(1)
            end
          rescue StandardError => e
            warn pastel.red("\nFailed to validate script:")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Show warnings (success case)
          # ------------------------------------------------------------
          unless validator.warnings.empty?
            validator.warnings.each do |warning|
              warn pastel.yellow("Warning: #{warning}")
            end
          end

          # ------------------------------------------------------------
          # Submit job
          # ------------------------------------------------------------
          return unless options[:submit]

          begin
            stdout, _, status = Open3.capture3('sbatch', file_path)

            if status.success?
              puts pastel.green("\nJob submitted successfully.")
              puts stdout
            else
              warn pastel.red("\nSlurm rejected the job submission.")
              warn pastel.red("#{stdout}\n")
              exit(1)
            end
          rescue StandardError => e
            warn pastel.red("\nFailed to submit job:")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          exit(0)

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          spinner&.error(pastel.red('(Unexpected error)'))
          warn pastel.red("\nAn unexpected error occurred while modifying the script:")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
