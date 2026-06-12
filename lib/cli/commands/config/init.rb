# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'yaml'
require 'fileutils'

require_relative '../../../services/sysinfo'

module AlcesJob
  module CLI
    module Commands
      class ConfigInit < Dry::CLI::Command
        AlcesJob::CLI.register 'config init', self
        desc 'This command generates the initial system info config and saves it'

        def initialize
          @config_path = YAML.load_file(File.expand_path('../../../../config/config.yaml', __dir__))['admin_config_file']
          @system_data = nil
        end

        def call(*)
          pastel = Pastel.new

          if Process.uid != 0
            puts pastel.red("\nThis command must be ran with elevated privileges\n")
            exit(1)
          end

          # Check config file
          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.update(title: 'checking for config')
          spinner.auto_spin
          if File.exist?(@config_path)
            data = YAML.load_file(@config_path)

            unless data.nil?
              spinner.error('(config exists)')
              puts pastel.green("\nA config already exists\n")
              exit(1)
            end

            spinner.success('(empty config)')
          else
            spinner.success('(no config)')
          end

          # Collecting system information
          spinner.update(title: 'collecting system info')
          spinner.auto_spin
          @system_data = Services::SysInfo.all_info
          spinner.success('(successful)')

          # Writing to config file
          spinner.update(title: 'writing config file')
          spinner.auto_spin
          begin
            FileUtils.mkdir_p(File.dirname(@config_path))
            File.write(@config_path, @system_data.to_yaml)
            spinner.success('(successful)')

            puts pastel.green("\nThe config file has been written to #{@config_path}\n")
            exit(0)
          rescue StandardError => e
            spinner.error('(writing error)')
            puts pastel.red("\nFailed to write config file: #{e.message}\n")
            exit(1)
          end
        end
      end
    end
  end
end
