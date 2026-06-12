# frozen_string_literal: true

require 'erb'
require 'ostruct'
require 'open3'
require 'yaml'

module AlcesJob
  module Services
    class Generator
      attr_reader :file_path

      def initialize(options)
        @context = OpenStruct.new(options)
        @template = @context.template || 'default'
        job_name = @context.job_name || 'default'
        @file_path = File.join(Dir.pwd, @context.output_file.nil? ? "job-#{job_name}.slurm" : @context.output_file)
      end

      def generate
        ERB.new(template, trim_mode: '-').result(binding)
      end

      def save(script = generate)
        File.write(@file_path, script)

        @file_path
      end

      def submit(file_path)
        stdout, _, status = Open3.capture3("sbatch #{file_path}")

        [stdout, status]
      end

      private

      def admin_path
        YAML.load_file(File.expand_path('../../config/config.yaml', __dir__))['admin_templates_folder']
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
