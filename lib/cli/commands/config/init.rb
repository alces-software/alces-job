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

        option :partition, type: :string, desc: 'The default partition to be used'

        option :account, type: :string,
                         desc: 'Specifies the Slurm account to charge'

        def initialize
          @admin_config_path = Services::Paths.new.admin_config_path
          @user_config_path = Services::Paths.new.user_config_path
        end

        def call(**options)
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
          if File.exist?(path)
            data = YAML.load_file(path)

            unless data.nil?
              spinner.error(pastel.red('(config exists)'))
              puts pastel.green("\nA config already exists\n")
              exit(1)
            end

            spinner.success(pastel.green('(empty config)'))
          else
            spinner.success(pastel.green('(no config)'))
          end

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
            FileUtils.mkdir_p(File.dirname(path))
            File.write(path, config.to_yaml)
            spinner.success(pastel.green('(successful)'))

            puts pastel.green("\nThe config file has been written to #{path}\n")
            exit(0)
          rescue StandardError => e
            spinner.error(pastel.red('(writing error)'))
            puts pastel.red("\nFailed to write config file: #{e.message}\n")
            exit(1)
          end
        end
      end
    end
  end
end
