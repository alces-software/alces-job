# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

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
          pastel = Pastel.new

          if validator.validate?
            puts pastel.green("\nValidation passed\n")
          else
            puts pastel.red("\nValidation failed:")
            validator.errors.each { |error| puts "- #{error}" }
          end

          exit(0) if validator.warnings.empty?

          puts 'Warnings:'
          validator.warnings.each { |warning| puts "- #{warning}" }

          exit(0)
        end
      end
    end
  end
end
