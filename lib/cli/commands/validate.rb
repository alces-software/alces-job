# frozen_string_literal: true

require 'dry/cli'

require_relative '../../services/slurm_script_validator'

module AlcesJob
  module CLI
    module Commands
      class Validate < Dry::CLI::Command
        desc 'Validates an existing sbatch script'
        argument :file_path, required: true, desc: 'Path to the sbatch/slurm script'

        AlcesJob::CLI.register 'validate', self

        def call(file_path:, **)
          validator = SlurmScriptValidator.new(file_path)
          if validator.validate?
            puts 'Validation passed.'
          else
            puts 'Validation failed:'

            validator.errors.each { |error| puts "- #{error}" }

          end

          return if validator.warnings.empty?

          puts 'Warnings:'

          validator.warnings.each { |warning| puts "- #{warning}" }
        end
      end
    end
  end
end
