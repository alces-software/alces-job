# frozen_string_literal: true

require 'dry/cli'
require 'yaml'

module AlcesJob
  module CLI
    module Commands
      class TemplateShow < Dry::CLI::Command
        AlcesJob::CLI.register 'template show', self
        desc 'Displays the contents of an available template'

        option :name, type: :string, desc: 'The name of the template to display'

        def initialize
          config = YAML.load_file(File.expand_path('../../../../config.yaml', __dir__))
          @admin_templates_folder = File.expand_path(config['admin_templates_folder'])
          @user_templates_folder = File.expand_path('~/.alces-job/templates')
          @builtin_templates_folder = File.expand_path('../../../../templates', __dir__)
        end

        def call(**options)
          return puts 'No template name supplied.' if options[:name].nil?

          path = template_path(options[:name])

          unless path
            puts "Template #{options[:name]} not found."
            return
          end

          puts "# Template: #{options[:name]}"
          puts "# Source: #{template_source(path)}"
          puts
          puts File.read(path)
        rescue Errno::ENOENT
          puts 'No template directory exists.'
        end

        private

        def template_path(name)
          candidate_paths = [
            File.join(@user_templates_folder, "#{name}.erb"),
            File.join(@admin_templates_folder, "#{name}.erb"),
            File.join(@builtin_templates_folder, "#{name}.erb")
          ]

          candidate_paths.find { |path| File.exist?(path) }
        end

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
