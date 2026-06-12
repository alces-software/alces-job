# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../services/template_validator'

module AlcesJob
  module CLI
    module Commands
      class TValidate < Dry::CLI::Command
        desc 'Validates a custom template'

        argument :name, required: true, desc: 'Name of the custom template'

        AlcesJob::CLI.register 'tvalidate', self
        def call(name:, **)
          template_path = File.expand_path("~/.alces-job/templates/#{name}.erb")
          validator = TemplateValidator.new(template_path)
          pastel = Pastel.new

          if validator.validate?
            puts pastel.green("\nTemplate validation passed\n")
          else
            puts pastel.red("\nTemplate validation failed:")
            validator.errors.each { |error| puts "- #{error}" }
          end

          exit(0) if validator.warnings.empty?

          puts pastel.yellow("\nWarnings:")
          validator.warnings.each { |warning| puts "- #{warning}" }
          exit(0)
        end
      end
    end
  end
end
