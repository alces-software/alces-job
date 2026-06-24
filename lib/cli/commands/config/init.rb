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
        desc 'This command generates the initial admin config'

        option :job_name, type: :string, aliases: ['-J'],
                          desc: 'Sets the Slurm job name for the generated Serial script'

        option :mem, type: :string,
                     desc: 'Sets the memory requirement for the job (e.g. 4G or 2000M)'

        option :time, type: :string, aliases: ['-t'],
                      desc: 'Sets the walltime limit for the Serial job'

        option :partition, type: :string, aliases: ['-p'],
                           desc: 'Specifies the Slurm partition or queue to use'

        option :module, type: :array, default: [],
                        desc: 'Loads environment modules before running the job'

        option :workdir, type: :string,
                         desc: 'Changes to the specified working directory in the job script'

        option :command, type: :string,
                         desc: 'Specifies the shell command to execute in the script'

        option :account, type: :string, aliases: ['-A'],
                         desc: 'Specifies the Slurm account to charge'

        def call(**options)
          admin_config_path = Services::Paths.new.admin_config_path
          pastel = Pastel.new

          if options.empty?
            puts pastel.red("\nNo flags have been provided\n")
            exit(1)
          end

          path = if Process.uid == 0
                   @admin_config_path
                 else
                   @user_config_path
                 end

          # Check config file
          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.update(title: 'checking for config file')
          spinner.auto_spin

          # Writing to config file
          spinner.update(title: 'writing config file')
          spinner.auto_spin
          config = { 'values' => {} }

          options.each_key do |key|
            key_str = key.to_s
            config['values'][key_str] = {
              'default' => options[key],
              'warn' => false
            }
          end

          begin
            FileUtils.mkdir_p(File.dirname(admin_config_path))
            File.write(admin_config_path, options.to_yaml)
            spinner.success(pastel.green('(successful)'))

            puts pastel.green("\nThe config file has been written to #{admin_config_path}\n")
            exit(0)
          rescue StandardError => e
            spinner.error(pastel.red('(writing error)'))
            puts pastel.red("\nFailed to write config file:\n#{e.message}\n")
            exit(1)
          end
        rescue StandardError => e
          spinner&.error('(command error)')
          puts pastel.red("\nAn error occurred while running the command:\n#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
