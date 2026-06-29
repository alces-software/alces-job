# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'yaml'

require_relative '../../../services/sys_info/sys_info'
require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class SysInfoUpdate < Dry::CLI::Command
        AlcesJob::CLI.register 'sysinfo update', self
        desc 'This command is used to update the system info file'

        option :partition, type: :boolean, default: false, desc: 'Update partitions info', aliases: ['-p']
        option :package, type: :boolean, default: false, desc: 'Update packages info', aliases: ['-k']
        option :all, type: :boolean, default: false, desc: 'Update all the system information', aliases: ['-a']

        def call(**options)
          pastel = Pastel.new

          system_info_file_path = if Process.uid.zero?
                                    Services::Paths.new.admin_system_info_path
                                  else
                                    Services::Paths.new.user_system_info_path
                                  end

          filtered_options = options.select { |_key, value| value }

          if filtered_options.empty?
            puts pastel.red("\nYou didn't specify any systeminformation to update.\n")
            exit(1)
          end

          # Load and parse system-info.yaml
          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.update(title: 'loading system info')
          spinner.auto_spin
          begin
            unless File.exist?(system_info_file_path)
              spinner.error(pastel.red('(No system info)'))
              warn pastel.red("\nThere is no system info file currently present use sysinfo init to create one.\n")
              exit(1)
            end
          rescue StandardError => e
            spinner.error(pastel.red('(Check failed)'))
            warn pastel.red("\nFailed to check if a system information file exists:\n#{e.message}\n")
            exit(1)
          end

          begin
            system_data = YAML.load_file(system_info_file_path)
          rescue StandardError => e
            spinner.error(pastel.red('(Load failed)'))
            warn pastel.red("\nFailed to load the system information file:\n#{e.message}\n")
            exit(1)
          end

          if system_data.nil?
            spinner.error(pastel.red('(Blank system info)'))
            warn pastel.red("\nThe system info you have contains no data generate a new one using sysinfo init.\n")
            exit(1)
          end
          spinner.success(pastel.green('(Successful)'))

          # Get system information
          spinner.update(title: 'collecting system info')
          spinner.auto_spin
          begin
            if filtered_options[:all].nil?
              filtered_options.each_pair do |key, _value|
                case key
                when :partition
                  system_data[:partitions] = Services::SysInfo.partition_info
                when :package
                  system_data[:packages] = Services::SysInfo.package_info
                end
              end
            else
              system_data = Services::SysInfo.all_info
            end
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to collect)'))
            warn pastel.red("\nFailed to collect system information:\n#{e.message}\n")
            exit(1)
          end
          spinner.success(pastel.green('(Successful)'))

          # New data to file
          spinner.update(title: 'writing system info file')
          spinner.auto_spin
          begin
            File.write(system_info_file_path, system_data.to_yaml)
            spinner.success(pastel.green('(Successful)'))
            puts pastel.green("\nThe system info file at #{system_info_file_path} has been updated.\n")
            exit(0)
          rescue StandardError => e
            spinner.error(pastel.red('(Writing error)'))
            warn pastel.red("\nFailed to update system info file:\n#{e.message}\n")
            exit(1)
          end
        rescue StandardError => e
          spinner&.error(pastel.red('(Command error)'))
          warn pastel.red("\nAn error occurred while running the command:\n#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
