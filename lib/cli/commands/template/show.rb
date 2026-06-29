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

        argument :template_name, required: true, type: :string, desc: 'The name of the template to display'

        def initialize
          paths = Services::Paths.new
          @admin_templates_folder = paths.admin_template_dir
          @user_templates_folder = paths.user_template_dir
          @builtin_templates_folder = File.expand_path('../../../../templates', __dir__)
        end

        def call(template_name:, **)
          pastel = Pastel.new

          # ------------------------------------------------------------
          # Validate input
          # ------------------------------------------------------------
          if template_name.to_s.strip.empty?
            warn pastel.red("\nNo template name was provided.\n")
            exit(1)
          end

          template_name = template_name.strip
          path = template_path(template_name)

          # ------------------------------------------------------------
          # Check template exists
          # ------------------------------------------------------------
          unless path
            warn pastel.red("\nTemplate not found: #{template_name}")
            warn pastel.yellow("Check the template name and try again.\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Read template
          # ------------------------------------------------------------
          begin
            puts
            puts "# Template: #{template_name}"
            puts "# Source: #{template_source(path)}"
            puts
            puts File.read(path)
            puts

            exit(0)
          rescue Errno::ENOENT
            warn pastel.red("\nTemplate file not found.")
            warn pastel.yellow("It may have been moved or deleted.\n")
            exit(1)
          rescue Errno::EACCES
            warn pastel.red("\nYou do not have permission to read this template.\n")
            exit(1)
          rescue StandardError => e
            warn pastel.red("\nFailed to read template.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          warn pastel.red("\nAn unexpected error occurred while running the command.")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end

        private

        # Finds template in user/admin/built-in locations
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

        # Determines template source
        # @return [String]
        def template_source(path)
          case path
          when /#{Regexp.escape(@user_templates_folder)}/ then 'user'
          when /#{Regexp.escape(@admin_templates_folder)}/ then 'admin'
          else 'built-in'
          end
        end
      end
    end
  end
end
