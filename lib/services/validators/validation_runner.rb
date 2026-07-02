# frozen_string_literal: true

require_relative 'slurm_script_validator'
require_relative '../plugins/validator_plugin_loader'

module AlcesJob
  module Services
    class ValidationRunner
      attr_reader :errors, :warnings, :results

      def initialize(
        file_path,
        system_info: SysInfo.load_info,
        plugin_loader: Plugins::ValidatorPluginLoader.new
      )
        @file_path = file_path
        @errors = []
        @warnings = []
        @results = []
        @system_info = system_info
        @plugin_loader = plugin_loader
      end

      def validate?
        validators = [
          {
            name: 'AlcesSlurmScriptValidator',
            validator: SlurmScriptValidator.new(
              @file_path,
              system_info: @system_info
            )
          }
        ]

        # ------------------------------------------------------------
        # Load validator classes found in the user's plugin directory
        # ------------------------------------------------------------
        @plugin_loader.find_plugins.each do |plugin_class|
          validators << {
            name: plugin_class.name.split('::').last,
            validator: plugin_class.new(
              @file_path,
              system_info: @system_info
            )
          }
        end

        # ------------------------------------------------------------
        # Run every built-in and user plugin validator
        # ------------------------------------------------------------
        validators.each do |validator_details|
          validator = validator_details[:validator]
          passed = validator.validate?

          result = {
            name: validator_details[:name],
            passed: passed,
            errors: validator.errors,
            warnings: validator.warnings
          }

          @results << result
          @errors.concat(validator.errors)
          @warnings.concat(validator.warnings)
        end

        @errors.empty?
      end
    end
  end
end
