# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'yaml'

require_relative '../../../services/sysinfo/sysinfo'

module AlcesJob
  module CLI
    module Commands
      class ConfigInit < Dry::CLI::Command
        AlcesJob::CLI.register 'config init', self
        desc 'This command generates the initial system info config and saves it'

        def initialize
          config = YAML.load_file('./config.yaml')
          @config_path = config['admin_config_file']
          @system_data = nil
        end

        def call(*)
          pastel = Pastel.new

          return puts pastel.red("\nThis command must be ran with elevated privileges\n") if Process.uid != 0

          puts

          # Check config file
          spinner = TTY::Spinner.new(
            '[:spinner] checking for config ...',
            success_mark: pastel.green('✔'),
            error_mark: pastel.red('✖')
          )

          if File.exist?(@config_path)
            data = YAML.load_file(@config_path)

            unless data.nil?
              spinner.error('(config exists)')
              puts pastel.green("\nA config already exists\n")
              return
            end

            spinner.success('(empty config)')
          else
            spinner.success('(no config)')
          end

          # Collecting system information
          spinner = TTY::Spinner.new(
            '[:spinner] collecting system info ...',
            success_mark: pastel.green('✔'),
            error_mark: pastel.red('✖')
          )

          spinner.auto_spin
          @system_data = SysInfo.getAllInfo
          spinner.success('(successful)')

          # Writing to config file
          spinner = TTY::Spinner.new(
            '[:spinner] writing config file ...',
            success_mark: pastel.green('✔'),
            error_mark: pastel.red('✖')
          )

          spinner.auto_spin
          File.write(@config_path, @system_data.to_yaml)
          spinner.success('(successful)')

          puts pastel.green("\nThe config file has been written to #{@config_path}\n")
        end
      end
    end
  end
end
