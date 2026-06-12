# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'yaml'

require_relative '../../../services/sysinfo'

module AlcesJob
  module CLI
    module Commands
      class ConfigUpdate < Dry::CLI::Command
        AlcesJob::CLI.register 'config update', self
        desc 'This command is used to update the system config.yaml'

        option :node, type: :boolean, default: false, desc: 'Update nodes info', aliases: ['-n']
        option :partition, type: :boolean, default: false, desc: 'Update partitions info',
                           aliases: ['-p']
        option :package, type: :boolean, default: false, desc: 'Update packages info',
                         aliases: ['-k']
        option :gpu, type: :boolean, default: false, desc: 'Update GPU count', aliases: ['-g']
        option :all, type: :boolean, default: false, desc: 'Update all the system information',
                     aliases: ['-a']

        def initialize
          @config_path = YAML.load_file(File.expand_path('../../../../config/config.yaml', __dir__))['admin_config_file']
          @system_data = nil
        end

        def call(**options)
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

          spinner.update(title: 'loading config')
          spinner.auto_spin

          unless File.exist?(@config_path)
            spinner.error('(no config)')
            puts pastel.red("\nThere is no config file currently present use config init to create one\n")
            exit(1)
          end

          @system_data = YAML.load_file(@config_path)

          if @system_data.nil?
            spinner.error('(blank config)')
            puts pastel.red("\nThe config you have contains no data generate a new one using config init\n")
            exit(1)
          end

          spinner.success('(successful)')

          # Get system information
          spinner.update(title: 'collecting system info')
          spinner.auto_spin

          if filtered_options[:all].nil?
            filtered_options.each_pair do |key, _value|
              case key
              when :node
                @system_data[:nodes] = Services::SysInfo.node_info
              when :partition
                @system_data[:partitions] = Services::SysInfo.partition_info
              when :package
                @system_data[:packages] = Services::SysInfo.package_info
              when :gpu
                @system_data[:gpu_total] = Services::SysInfo.gpu_info
              end
            end
          else
            @system_data = Services::SysInfo.all_info
          end

          spinner.success('(successful)')

          # New data to file
          spinner.update(title: 'writing config file')
          spinner.auto_spin

          begin
            File.write(@config_path, @system_data.to_yaml)
            spinner.success('(successful)')

            puts pastel.green("\nThe config file at #{@config_path} has been updated\n")
            exit(0)
          rescue StandardError => e
            spinner.error('(writing error)')
            puts pastel.red("\nFailed to update config file: #{e.message}\n")
            exit(1)
          end
        end
      end
    end
  end
end
