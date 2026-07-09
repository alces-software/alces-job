# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class TemplateList < Dry::CLI::Command
        AlcesJob::CLI.register 'template list', self

        desc 'Lists available templates from built-in, admin, and user locations'

        def call(*)
          paths = Services::Paths.new
          pastel = Pastel.new
          templates = {}

          # ------------------------------------------------------------
          # Scan template directories
          # ------------------------------------------------------------
          begin
            scan_templates(File.expand_path('../../../../templates', __dir__), 'built-in', templates)
            scan_templates(paths.admin_config_path, 'admin', templates)
            scan_templates(paths.user_template_dir, 'user', templates)
          rescue StandardError => e
            warn pastel.red("\nFailed to scan template directories.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # No templates found
          # ------------------------------------------------------------
          if templates.empty?
            warn pastel.red("\nNo templates found.\n")
            exit(0)
          end

          # ------------------------------------------------------------
          # Display templates
          # ------------------------------------------------------------
          puts pastel.green("\nAvailable templates:")
          templates.each do |name, source|
            puts "#{name} (#{source})"
          end
          puts

          exit(0)

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          warn pastel.red("\nAn unexpected error occurred while running the command.")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end

        private

        # Searches directories for templates and collects results
        # @param [String] folder
        # @param [String] source
        # @param [Hash] templates
        # @return [Array]
        def scan_templates(folder, source, templates)
          return templates unless File.directory?(folder)

          Dir.glob(File.join(folder, '*.erb')).each do |path|
            name = File.basename(path, '.erb')
            templates[name] ||= source
          end
        rescue Errno::ENOENT
          templates
        end
      end
    end
  end
end
