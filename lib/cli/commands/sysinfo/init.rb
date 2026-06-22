# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'yaml'
require 'fileutils'

require_relative '../../../services/sys_info/sys_info'

module AlcesJob
  module CLI
    module Commands
      class SysInfoInit < Dry::CLI::Command
        AlcesJob::CLI.register 'sysinfo init', self
        desc 'This command generates the initial system info and saves it'

        def initialize
          @system_info_path = YAML.load_file(File.expand_path('../../../../config/config.yaml', __dir__))['system_info_file']
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

          spinner.update(title: 'checking for system info file')
          spinner.auto_spin
          if File.exist?(@system_info_path)
            data = YAML.load_file(@system_info_path)

            unless data.nil?
              spinner.error(pastel.red('(config exists)'))
              puts pastel.green("\nA system info already exists\n")
              exit(1)
            end

            spinner.success(pastel.green('(empty system info)'))
          else
            spinner.success(pastel.green('(no system info)'))
          end

          # Collecting system information
          spinner.update(title: 'collecting system info')
          spinner.auto_spin
          @system_data = Services::SysInfo.all_info
          spinner.success(pastel.green('(successful)'))

          # Writing to system info file
          spinner.update(title: 'writing system info file')
          spinner.auto_spin
          begin
            FileUtils.mkdir_p(File.dirname(@system_info_path))
            File.write(@system_info_path, @system_data.to_yaml)
            spinner.success(pastel.green('(successful)'))

            puts pastel.green("\nThe system info file has been written to #{@system_info_path}\n")
            exit(0)
          rescue StandardError => e
            spinner.error(pastel.red('(writing error)'))
            puts pastel.red("\nFailed to write system info file: #{e.message}\n")
            exit(1)
          end
        end
      end
    end
  end
end
