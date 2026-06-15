# frozen_string_literal: true

require 'dry/cli'
require 'yaml'
require 'pastel'

module AlcesJob
  module CLI
    module Commands
      class TemplateShow < Dry::CLI::Command
        AlcesJob::CLI.register 'template show', self
        desc 'Displays the contents of an available template'

        option :name, type: :string, desc: 'The name of the template to display'

        def initialize
          config = YAML.load_file(File.expand_path('../../../../config/config.yaml', __dir__))
          @admin_templates_folder = File.expand_path(config['admin_templates_folder'])
          @user_templates_folder = File.expand_path('~/.alces-job/templates')
          @builtin_templates_folder = File.expand_path('../../../../templates', __dir__)
        end

        def call(**options)
          pastel = Pastel.new
          if options[:name].nil?
            puts pastel.red("\nNo template name supplied\n")
            exit(1)
          end

          path = template_path(options[:name])

          unless path
            puts pastel.red("\nTemplate #{options[:name]} not found\n")
            exit(1)
          end

          puts "# Template: #{options[:name]}"
          puts "# Source: #{template_source(path)}"
          puts
          puts File.read(path)
          exit(0)
        rescue Errno::ENOENT
          puts pastel.red("\nNo template directory exists\n")
          exit(0)
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
