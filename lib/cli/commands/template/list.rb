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

          scan_templates(File.expand_path('../../../../templates', __dir__), 'built-in', templates)
          scan_templates(paths.admin_config_path, 'admin', templates)
          scan_templates(paths.user_template_dir, 'user', templates)

          if templates.empty?
            puts pastel.red("\nNo templates found\n")
            exit(0)
          end

          templates.each do |name, source|
            puts "#{name} (#{source})"
          end
          exit(0)
        end

        private

        def scan_templates(folder, source, templates)
          return unless File.directory?(folder)

          Dir.glob(File.join(folder, '*.erb')).each do |path|
            name = File.basename(path, '.erb')
            templates[name] ||= source
          end
        rescue Errno::ENOENT
          nil
        end
      end
    end
  end
end
