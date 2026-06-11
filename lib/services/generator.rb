# frozen_string_literal: true

require 'erb'
require 'ostruct'
require 'open3'
require 'yaml'

module AlcesJob
  module Services
    class Generator
      def initialize(options)
        @context = OpenStruct.new(options)
        @template = @context.template || 'default'
      end

      def generate
        ERB.new(template, trim_mode: '-').result(binding)
      end

      def save(script = generate)
        file_name = 'job.sbatch'

        file_name = @context.output_file unless @context.output_file.nil?
        path = File.join(Dir.pwd, file_name)

        File.write(path, script)

        path
      end

      def submit(file_path)
        stdout, _, status = Open3.capture3("sbatch #{file_path}")

        [stdout, status]
      end

      private

      def admin_path
        config = YAML.load_file(File.join(Dir.pwd, 'config.yaml'))

        config['admin_templates_folder']
      end

      def template
        built_in_path = File.join(__dir__, '../../templates', "#{@template}.erb")
        user_path = File.join(File.expand_path('~/.alces-job/templates'), "#{@template}.erb")
        admin_file = File.join(File.expand_path(admin_path), "#{@template}.erb")

        if File.exist?(user_path)
          File.read(user_path)
        elsif File.exist?(admin_file)
          File.read(admin_file)
        elsif File.exist?(built_in_path)
          File.read(built_in_path)
        else
          raise "Template #{@template} not found in built-in or user templates"
        end
      end
    end
  end
end
