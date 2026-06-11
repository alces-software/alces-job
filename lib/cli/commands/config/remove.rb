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

        option :nodes, type: :boolean, default: false, desc: 'Targets nodes'
        option :partitions,  type: :boolean, default: false, desc: 'Targets partitions'

        def initialize
          config = YAML.load_file(File.expand_path('../../../../config.yaml', __dir__))
          @config_path = config['admin_config_file']
          @system_data = nil
        end

        def call(**options)
          selected = options.select { |_, v| v }.keys

          if selected.size != 1
            puts 'You can only specify one target'
            exit(1)
          end

          puts 'hello'
        end
      end
    end
  end
end
