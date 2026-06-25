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

          begin
            scan_templates(File.expand_path('../../../../templates', __dir__), 'built-in', templates)
            scan_templates(paths.admin_config_path, 'admin', templates)
            scan_templates(paths.user_template_dir, 'user', templates)
          rescue StandardError => e
            puts pastel.red("\nAn error occurred while scanning the directories:\n#{e.message}\n")
            exit(1)
          end

          if templates.empty?
            puts pastel.red("\nNo templates found.\n")
            exit(0)
          end

          puts pastel.green("\nAvailable profiles:")
          templates.each do |name, path|
            puts "#{name} ~ #{path}"
          end
          puts

          exit(0)
        rescue StandardError => e
          puts pastel.red("\nAn error occurred while running the command:\n#{e.message}\n")
          exit(1)
        end

        private

        # Searches through a directory and and adds the available templates to an array
        # @param [String] folder
        # @param [String] source
        # @param [Hash] templates
        # @return [Hash]
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
