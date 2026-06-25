# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'

require_relative '../../../services/validators/slurm_script_validator'

module AlcesJob
  module CLI
    module Commands
      class Validate < Dry::CLI::Command
        AlcesJob::CLI.register 'validate script', self
        desc 'Validates an existing sbatch script'

        argument :file_path, required: true, desc: 'Path to the sbatch/slurm script'

        def call(file_path:, **)
          pastel = Pastel.new

          if file_path.to_s.strip.empty?
            puts pastel.red("\nNo template name was provided.\n")
            exit(1)
          end

          puts
          spinner = TTY::Spinner.new(
            '[:spinner] validating script ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.auto_spin
          begin
            validator = AlcesJob::Services::SlurmScriptValidator.new(File.expand_path(file_path, Dir.pwd))
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to validate)'))
            puts pastel.red("\nAn error occurred while validating the script:\n#{e.message}\n")
            exit(1)
          end
          spinner.success(pastel.green('(Validation complete)'))

          if validator.validate?
            puts pastel.green("\nValidation passed\n")
          else
            puts pastel.red("\nValidation failed:")
            validator.errors.each { |error| puts "- #{error}" }
          end

          unless validator.warnings.empty?
            puts pastel.yellow("\nWarnings:")
            validator.warnings.each { |warning| puts "- #{warning}" }
          end

          exit(0)
        rescue StandardError => e
          spinner&.error(pastel.red('(Command error)'))
          puts pastel.red("\nAn error occurred while running the command:\n#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
