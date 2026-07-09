# frozen_string_literal: true

require_relative '../paths/paths'

module AlcesJob
  module Services
    module Plugins
      class ValidatorPluginLoader
        def initialize(paths: Paths.new)
          @paths = paths
        end

        # Get's all the plugins in a directory
        def find_plugins
          admin_plugins = find_plugins_in(
            @paths.admin_validator_plugin_dir
          )

          user_plugins = find_plugins_in(
            @paths.user_validator_plugin_dir
          )

          admin_plugins + user_plugins
        end

        private

        # Get all the plugins from a directory
        # @params [String] plugin directory
        # @return [Array]
        def find_plugins_in(plugin_directory)
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
