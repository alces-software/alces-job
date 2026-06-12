# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'yaml'

module AlcesJob
  module CLI
    module Commands
      class ConfigEditRemove < Dry::CLI::Command
        AlcesJob::CLI.register 'config edit remove', self
        desc 'Used to remove items from the the admin config file e.g. partitions, nodes'

        option :nodes, type: :string, desc: 'The nodes you want to remove from the system config'
        option :partitions, type: :string, desc: 'The partitions you want to remove from the system config'

        def initialize
          @config_path = YAML.load_file(File.expand_path('../../../../../config/config.yaml', __dir__))['admin_config_file']
          @system_data = nil
        end

        def call(**options)
          pastel = Pastel.new

          if Process.uid != 0
            puts pastel.red("\nThis command must be ran with elevated privileges\n")
            exit(1)
          end

          unless File.exist?(@config_path)
            puts pastel.red("\nThere is no config to edit generate a config with config init\n")
            exit(1)
          end

          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.update(title: 'removing from config')
          spinner.auto_spin

          @system_data = YAML.load_file(@config_path)

          if options[:nodes]
            nodes_to_delete = options[:nodes].split(',').map(&:strip)
            node_count = @system_data[:nodes].length

            @system_data[:nodes] = @system_data[:nodes].reject do |node|
              nodes_to_delete.include?(node[:node])
            end

            puts pastel.red("\nRemoved no nodes from the config\n") if node_count == @system_data[:nodes].length
          end

          if options[:partitions]
            partitions_to_delete = options[:partitions].split(',').map(&:strip)
            partition_count = @system_data[:partitions].length

            @system_data[:partitions] = @system_data[:partitions].reject do |partition|
              partitions_to_delete.include?(partition[:partition])
            end

            puts pastel.red("\nRemoved no partitions from the config\n") if partition_count == @system_data[:partitions]
          end

          spinner.success('(successful)')
          spinner.update(title: 'updating config file')
          spinner.auto_spin

          begin
            File.write(@config_path, @system_data.to_yaml)
            spinner.success('(successful)')

            puts pastel.green("\nSuccessfully remove the items from the config\n")
            exit(0)
          rescue StandardError => e
            spinner.error('(writing error)')
            puts pastel.red("\nFailed to remove the items from the config: #{e.message}\n")
            exit(1)
          end
        end
      end
    end
  end
end
