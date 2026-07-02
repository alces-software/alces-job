# frozen_string_literal: true

require_relative 'slurm_script_validator'
require_relative 'new_dummy_validator'

module AlcesJob
  module Services
    class ValidationRunner
      attr_reader :errors, :warnings, :results

      def initialize(file_path, system_info: SysInfo.load_info)
        @file_path = file_path
        @errors = []
        @warnings = []
        @results = []
        @system_info = system_info
      end

      def validate?
        validators = [
          {
            name: 'AlcesSlurmScriptValidator',
            validator: SlurmScriptValidator.new(
              @file_path,
              system_info: @system_info
            )
          },
          {
            name: 'NewDummyValidator',
            validator: NewDummyValidator.new(
              @file_path,
              system_info: @system_info
            )
          }
        ]

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
