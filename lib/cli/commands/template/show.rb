# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class TemplateShow < Dry::CLI::Command
        AlcesJob::CLI.register 'template show', self
        desc 'Displays the contents of an available template'

        argument :template_name, require: false, type: :string, desc: 'The name of the template to display'

        def initialize
          paths = Services::Paths.new
          @admin_templates_folder = paths.admin_template_dir
          @user_templates_folder = paths.user_template_dir
          @builtin_templates_folder = File.expand_path('../../../../templates', __dir__)
        end

        def call(template_name: nil, **)
          pastel = Pastel.new

          if template_name.nil? || template_name.strip.empty?
            puts pastel.red("\nNo template name supplied.\n")
            exit(1)
          end

          path = template_path(template_name)

          unless path
            warn pastel.red("\nTemplate #{template_name} not found.\n")
            exit(1)
          end

          begin
            puts
            puts "# Template: #{template_name}"
            puts "# Source: #{template_source(path)}"
            puts
            puts File.read(path)
            puts
            exit(0)
          rescue StandardError => e
            warn pastel.red("\nAn error occurred while reading the template:\n#{e.message}\n")
            exit(1)
          end
        rescue StandardError => e
          warn pastel.red("\nAn error occurred while running the command:\n#{e.message}\n")
          exit(1)
        end

        private

        # Searches for the directories for where the template is stored
        # @param [String] name
        # @return [String]
        def template_path(name)
          candidate_paths = [
            File.join(@user_templates_folder, "#{name}.erb"),
            File.join(@admin_templates_folder, "#{name}.erb"),
            File.join(@builtin_templates_folder, "#{name}.erb")
          ]

          candidate_paths.find { |path| File.exist?(path) }
        end

        # Determines where the template is stored e.g. user, admin or built in
        # @return [String]
        def template_source(path)
          case path
          when /#{Regexp.escape(@user_templates_folder)}/ then 'user'
          when /#{Regexp.escape(@admin_templates_folder)}/ then 'admin'
          else 'built-in'
          end
        end
      end
    end
  end
end
