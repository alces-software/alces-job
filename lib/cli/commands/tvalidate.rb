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

        AlcesJob::CLI.register 'template-validate', self
        def call(name:, **)
          pastel = Pastel.new
          template_path = File.expand_path("~/.alces-job/templates/#{name}.erb")
          validator = TemplateValidator.new(template_path)
          if validator.validate?
            puts pastel.green('Template validation passed.')
          else

            puts pastel.red('Template validation failed:')
            validator.errors.each { |error| puts "- #{error}" }
          end

          return if validator.warnings.empty?

          puts pastel.yellow('Warnings:')
          validator.warnings.each { |warning| puts "- #{warning}" }
        end
      end
    end
  end
end
