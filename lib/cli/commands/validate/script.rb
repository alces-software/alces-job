# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'

require_relative '../../../services/validators/slurm_script_validator'

module AlcesJob
  module CLI
    module Commands
      class ValidateScript < Dry::CLI::Command
        AlcesJob::CLI.register 'validate script', self

        desc 'Validates an existing sbatch script'

        argument :file_path, required: true, desc: 'Path to the sbatch/slurm script'

        def call(file_path:, **)
          pastel = Pastel.new

          # ------------------------------------------------------------
          # Validate input
          # ------------------------------------------------------------
          if file_path.to_s.strip.empty?
            warn pastel.red("\nNo file path was provided.\n")
            exit(1)
          end

          puts

          spinner = TTY::Spinner.new(
            '[:spinner] validating script ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          # ------------------------------------------------------------
          # Initialise validator
          # ------------------------------------------------------------
          spinner.auto_spin

          begin
            validator = AlcesJob::Services::SlurmScriptValidator.new(File.expand_path(file_path, Dir.pwd))
          rescue StandardError => e
            spinner.error(pastel.red('(Failed)'))
            warn pastel.red("\nFailed to initialise validator.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Validated)'))

          # ------------------------------------------------------------
          # Validation result
          # ------------------------------------------------------------
          if validator.validate?
            puts pastel.green("\nValidation passed.\n")
          else
            warn pastel.red("\nValidation failed.")
            validator.errors.each do |error|
              warn pastel.red("- #{error}")
            end
            puts
          end

          # ------------------------------------------------------------
          # Warnings
          # ------------------------------------------------------------
          unless validator.warnings.empty?
            warn pastel.yellow("\nWarnings:")
            validator.warnings.each do |warning|
              warn pastel.yellow("- #{warning}")
            end

            puts
          end

          exit(0)

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          spinner&.error(pastel.red('(Unexpected error)'))
          warn pastel.red("\nAn unexpected error occurred while running the command.")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
