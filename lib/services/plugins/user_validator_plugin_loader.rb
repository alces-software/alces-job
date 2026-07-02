# frozen_string_literal: true

require_relative '../paths/paths'

module AlcesJob
  module Services
    module Plugins
      class UserValidatorPluginLoader
        def initialize(paths: Paths.new)
          @paths = paths
        end

        def plugin_directory
          @paths.user_validator_plugin_dir
        end

        def find_plugins
          return [] unless Dir.exist?(plugin_directory)

          external_validators = []

          Dir.glob(File.join(plugin_directory, '*.rb')).each do |file|
            require file

            class_name = File.basename(file, '.rb')
              .split('_')
              .map(&:capitalize)
              .join

            validator_class = Object.const_get(class_name)

            external_validators << validator_class
          rescue LoadError, NameError => e
            warn "Failed to load plugin from #{file}: #{e.message}"
          end

          external_validators
        end
      end
    end
  end
end
