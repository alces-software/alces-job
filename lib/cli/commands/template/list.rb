# frozen_string_literal: true

require 'dry/cli'
require 'yaml'

module AlcesJob
  module CLI
    module Commands
      class TemplateList < Dry::CLI::Command
        AlcesJob::CLI.register 'template list', self
        desc 'Lists available templates from built-in, admin, and user locations'

        def initialize
          config = YAML.load_file(File.expand_path('../../../../config/config.yaml', __dir__))
          @admin_templates_folder = File.expand_path(config['admin_templates_folder'])
          @user_templates_folder = File.expand_path('~/.alces-job/templates')
          @builtin_templates_folder = File.expand_path('../../../../templates', __dir__)
        end

        def call(*)
          templates = {}

          scan_templates(@builtin_templates_folder, 'built-in', templates)
          scan_templates(@admin_templates_folder, 'admin', templates)
          scan_templates(@user_templates_folder, 'user', templates)

          if templates.empty?
            puts 'No templates found.'
            return
          end

          templates.each do |name, source|
            puts "#{name} (#{source})"
          end
        end

        private

        def scan_templates(folder, source, templates)
          return unless File.directory?(folder)

          Dir.glob(File.join(folder, '*.erb')).sort.each do |path|
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
