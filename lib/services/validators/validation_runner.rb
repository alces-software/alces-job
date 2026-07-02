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
          SlurmScriptValidator.new(@file_path, system_info: @system_info),
          NewDummyValidator.new(@file_path, system_info: @system_info)
        ]
        validators.each do |validator|
          passed = validator.validate?

          result = {
            name: validator.class.name.split('::').last,
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
