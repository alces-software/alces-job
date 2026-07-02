# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'yaml'
require 'fileutils'

require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class ConfigInit < Dry::CLI::Command
        AlcesJob::CLI.register 'config init', self
        desc 'Generate an initial user or admin configuration file'

        option :job_name, type: :string, aliases: ['-J'], desc: 'Slurm job name'
        option :mem, type: :string, desc: 'Memory requirement (e.g. 4G, 2000M)'
        option :time, type: :string, aliases: ['-t'], desc: 'Walltime limit'
        option :partition, type: :string, aliases: ['-p'], desc: 'Slurm partition/queue'
        option :module, type: :array, default: [], desc: 'Environment modules to load'
        option :workdir, type: :string, desc: 'Working directory for the job'
        option :command, type: :string, desc: 'Command to execute in the job script'
        option :account, type: :string, aliases: ['-A'], desc: 'Slurm account name'
        option :output_file, type: :string, aliases: ['-o'], desc: 'Output filename for script'
        option :error, type: :string, aliases: ['-e'], desc: 'Stderr file path'
        option :mail_user, type: :string, desc: 'Email address for job notifications'
        option :mail_type, type: :string, desc: 'Notification type (BEGIN, END, FAIL, etc.)'
        option :submit, type: :boolean, default: false, desc: 'Submit the job immediately after generation'
        option :editor, type: :string, desc: 'Default editor to use for manual script editing'
        option :module, type: :array, aliases: ['-m'], default: [], desc: 'Loads environment modules before running the job'

        def call(**options)
          pastel = Pastel.new

          options = options.reject { |_, value| value == [] }
          options = options.select { |_, value| value }
          options[:modules] = AlcesJob::Services.module_extractor(ARGV)

          if options.empty?
            warn pastel.red("\nNo configuration options were provided. Use --help to see available flags.\n")
            exit(1)
          end

          path = if Process.uid.zero?
                   Services::Paths.new.admin_config_path
                 else
                   Services::Paths.new.user_config_path
                 end

          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          # ------------------------------------------------------------
          # Check existing config
          # ------------------------------------------------------------
          spinner.update(title: 'checking for existing configuration file')
          spinner.auto_spin

          begin
            if File.exist?(path)
              data = YAML.load_file(path)

              if data
                spinner.error(pastel.red('(Already exists)'))
                warn pastel.red("\nA configuration file already exists at:\n#{path}")
                warn pastel.yellow("Remove it or edit it manually if you want to regenerate it.\n")
                exit(1)
              end

              spinner.success(pastel.green('(Empty file)'))
            else
              spinner.success(pastel.green('(Not found)'))
            end
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to check)'))
            warn pastel.red("\nFailed to check config.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Write config file
          # ------------------------------------------------------------
          spinner.update(title: 'writing configuration file')
          spinner.auto_spin

          config = { 'flags' => {} }

          options.each_key do |key|
            config['flags'][key.to_s] = {
              'default' => options[key],
              'warn' => false
            }
          end

          begin
            FileUtils.mkdir_p(File.dirname(path))
            File.write(path, config.to_yaml)

            spinner.success(pastel.green('(Completed)'))

            puts pastel.green("\nConfiguration file created successfully:\n#{path}\n")

            exit(0)
          rescue Errno::ENOSPC
            spinner.error(pastel.red('(Disk full)'))
            warn pastel.red("\nUnable to write configuration file: disk space is full.\n")
            exit(1)
          rescue Errno::EACCES, Errno::EROFS
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red(
              "\nPermission denied while writing configuration file.\n" \
              "Check your access rights or filesystem permissions:\n#{path}\n"
            )
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Write failed)'))
            warn pastel.red("\nFailed to write configuration file:")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          spinner&.error(pastel.red('(Unexpected error)'))
          warn pastel.red("\nAn unexpected error occurred while creating the config:")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
