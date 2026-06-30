# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'

require_relative '../../../services/validators/template_validator'
require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class ValidateTemplate < Dry::CLI::Command
        AlcesJob::CLI.register 'validate template', self

        desc 'Validates a custom template'

        argument :template_name, required: true, desc: 'Name of the custom template'

        def call(template_name:, **)
          pastel = Pastel.new

          # ------------------------------------------------------------
          # Validate input
          # ------------------------------------------------------------
          if template_name.to_s.strip.empty?
            warn pastel.red("\nNo template name was provided.\n")
            exit(1)
          end

          spinner = TTY::Spinner.new(
            '[:spinner] validating template ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          # ------------------------------------------------------------
          # Initialise validator
          # ------------------------------------------------------------
          spinner.auto_spin

          begin
            validator = TemplateValidator.new(Services::Paths.new.user_template_path(template_name.strip))
          rescue StandardError => e
            spinner.error(pastel.red('(Failed)'))
            warn pastel.red("\nFailed to initialise template validator.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Validated)'))

          # ------------------------------------------------------------
          # Validation result
          # ------------------------------------------------------------
          if validator.validate?
            puts pastel.green("\nTemplate validation passed.\n")
          else
            warn pastel.red("\nTemplate validation failed.")

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
