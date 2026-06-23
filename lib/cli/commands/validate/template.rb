# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../../services/validators/template_validator'
require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class TValidate < Dry::CLI::Command
        AlcesJob::CLI.register 'validate template', self
        desc 'Validates a custom template'

        argument :name, required: true, desc: 'Name of the custom template'

        def call(name:, **)
          pastel = Pastel.new

          if name.to_s.strip.empty?
            puts pastel.red("\nNo template name was provided\n")
            exit(1)
          end

          validator = TemplateValidator.new(AlcesJob::Paths.new.user_template_path(name.strip))

          if validator.validate?
            puts pastel.green("\nTemplate validation passed\n")
          else
            puts pastel.red("\nTemplate validation failed:")
            validator.errors.each { |error| puts "- #{error}" }
          end

          unless validator.warnings.empty?
            puts pastel.yellow("\nWarnings:")
            validator.warnings.each { |warning| puts "- #{warning}" }
          end

          exit(0)
        end
      end
    end
  end
end
