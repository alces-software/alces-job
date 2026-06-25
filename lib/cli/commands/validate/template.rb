# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'

require_relative '../../../services/validators/template_validator'
require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class TValidate < Dry::CLI::Command
        AlcesJob::CLI.register 'validate template', self
        desc 'Validates a custom template'

        argument :template_name, required: true, desc: 'Name of the custom template'

        def call(template_name:, **)
          pastel = Pastel.new

          if template_name.to_s.strip.empty?
            puts pastel.red("\nNo template name was provided.\n")
            exit(1)
          end

          spinner = TTY::Spinner.new(
            '[:spinner] validating script ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.auto_spin
          begin
            validator = TemplateValidator.new(Services::Paths.new.user_template_path(template_name.strip))
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to validate)'))
            puts pastel.red("\nAn error occurred while validating the template:\n#{e.message}\n")
            exit(1)
          end
          spinner.success(pastel.green('(Validation complete)'))

          if validator.validate?
            puts pastel.green("\nTemplate validation passed.\n")
          else
            puts pastel.red("\nTemplate validation failed:")
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
