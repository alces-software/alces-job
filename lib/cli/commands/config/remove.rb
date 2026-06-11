# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'yaml'
require 'fileutils'

module AlcesJob
  module CLI
    module Commands
      class ConfigRemove < Dry::CLI::Command
        AlcesJob::CLI.register 'config remove', self
        desc 'Used to remove items from the the admin config file e.g. partitions, nodes'

        option :nodes, type: :string, desc: 'The nodes you want to remove from the system config'
        option :partitions, type: :string, desc: 'The partitions you want to remove from the system config'

        def initialize
          config = YAML.load_file(File.expand_path('../../../../config.yaml', __dir__))
          @config_path = config['admin_config_file']
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

          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✔'),
            error_mark: pastel.red('✖')
          )

          spinner.update(title: 'removing from config')
          spinner.auto_spin

          @system_data = YAML.load_file(@config_path)

          if options[:nodes]
            nodes_to_delete = options[:nodes].split(',').map(&:strip)

            @system_data['nodes'] = @system_data['nodes'].reject do |node|
              nodes_to_delete.include?(node['node'])
            end
          end

          if options[:partitions]
            partitions_to_delete = options[:partitions].split(',').map(&:strip)

            @system_data['partitions'] = @system_data['partitions'].reject do |partition|
              partitions_to_delete.include?(partition['partition'])
            end
          end

          spinner.success('(successful)')
          spinner.update(title: 'updating config file')
          spinner.auto_spin

          File.write(@config_path, @system_data)

          spinner.success('(successful)')

          puts pastel.green("\nSuccessfully remove the items from the config\n")
          exit(0)
        end
      end
    end
  end
end
