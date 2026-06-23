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

        option :node, type: :boolean, default: false, desc: 'Update nodes info', aliases: ['-n']
        option :partition, type: :boolean, default: false, desc: 'Update partitions info',
                           aliases: ['-p']
        option :package, type: :boolean, default: false, desc: 'Update packages info',
                         aliases: ['-k']
        option :gpu, type: :boolean, default: false, desc: 'Update GPU count', aliases: ['-g']
        option :all, type: :boolean, default: false, desc: 'Update all the system information',
                     aliases: ['-a']

        def call(**options)
          system_info_file_path = Services::Paths.new.system_info_path
          pastel = Pastel.new

          if Process.uid != 0
            puts pastel.red("\nThis command must be ran with elevated privileges\n")
            exit(1)
          end

          filtered_options = options.select { |_key, value| value }

          if filtered_options.empty?
            puts pastel.red("\nYou didn't specify any systeminformation to update\n")
            exit(1)
          end

          # Load and parse config.yaml
          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.update(title: 'loading system info')
          spinner.auto_spin

          unless File.exist?(system_info_file_path)
            spinner.error(pastel.red('(no system info)'))
            puts pastel.red("\nThere is no config file currently present use config init to create one\n")
            exit(1)
          end

          system_data = YAML.load_file(system_info_file_path)

          if system_data.nil?
            spinner.error(pastel.red('(blank system info)'))
            puts pastel.red("\nThe config you have contains no data generate a new one using config init\n")
            exit(1)
          end

          spinner.success(pastel.green('(successful)'))
          # Get system information
          spinner.update(title: 'collecting system info')
          spinner.auto_spin

          if filtered_options[:all].nil?
            filtered_options.each_pair do |key, _value|
              case key
              when :node
                system_data[:nodes] = Services::SysInfo.node_info
              when :partition
                system_data[:partitions] = Services::SysInfo.partition_info
              when :package
                system_data[:packages] = Services::SysInfo.package_info
              when :gpu
                system_data[:gpu_total] = Services::SysInfo.gpu_info
              end
            end
          else
            system_data = Services::SysInfo.all_info
          end

          spinner.success(pastel.green('(successful)'))

          # New data to file
          spinner.update(title: 'writing system info file')
          spinner.auto_spin

          begin
            File.write(system_info_file_path, system_data.to_yaml)
            spinner.success(pastel.green('(successful)'))

            puts pastel.green("\nThe system info file at #{system_info_file_path} has been updated\n")
            exit(0)
          rescue StandardError => e
            spinner.error(pastel.red('(writing error)'))
            puts pastel.red("\nFailed to update system info file: #{e.message}\n")
            exit(1)
          end
        end
      end
    end
  end
end
