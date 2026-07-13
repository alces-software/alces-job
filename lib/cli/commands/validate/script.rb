# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'

require_relative '../../../services/validators/validation_runner'

module AlcesJob
  module CLI
    module Commands
      class ValidateScript < Dry::CLI::Command
        AlcesJob::CLI.register 'validate script', self

        desc 'Runs all validators against an existing sbatch script'

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

          # ------------------------------------------------------------
          # Set up progress spinner
          # ------------------------------------------------------------
          spinner = TTY::Spinner.new(
            '[:spinner] running validators ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.auto_spin

          # ------------------------------------------------------------
          # Initialise validation runner and run all validators
          # ------------------------------------------------------------
          begin
            runner = AlcesJob::Services::ValidationRunner.new(
              File.expand_path(file_path, Dir.pwd)
            )

            valid = runner.validate?
          rescue StandardError => e
            spinner.error(pastel.red('(Failed)'))
            warn pastel.red("\nFailed to run validators.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Complete)'))

          # ------------------------------------------------------------
          # Display validation results for each validator
          # ------------------------------------------------------------
          puts pastel.bold.magenta(
            "\nValidation Results for #{File.basename(file_path)}\n"
          )

          runner.results.each do |result|
            puts pastel.bold.cyan("Validator: #{result[:name]}")

            if result[:passed]
              puts pastel.green('  ✓ Passed')
            else
              puts pastel.red('  ✗ Failed')
            end

            # ------------------------------------------------------------
            # Display errors returned by this validator
            # ------------------------------------------------------------
            unless result[:errors].empty?
              puts pastel.red('  Errors:')

              result[:errors].each do |error|
                puts pastel.red("    - #{error}")
              end
            end

            # ------------------------------------------------------------
            # Display warnings returned by this validator
            # ------------------------------------------------------------
            unless result[:warnings].empty?
              puts pastel.yellow('  Warnings:')

              result[:warnings].each do |warning|
                puts pastel.yellow("    - #{warning}")
              end
            end

            puts
          end

          # ------------------------------------------------------------
          # Return a non-zero exit code when any validator failed
          # ------------------------------------------------------------
          exit(valid ? 0 : 1)

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
