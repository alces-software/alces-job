# frozen_string_literal: true

require 'erb'
require 'ostruct'
require 'open3'

require_relative '../paths/paths'
require_relative '../prepare/prepare'

module AlcesJob
  module Services
    class ScriptGenerator
      attr_reader :file_path

      def initialize(options)
        @context = OpenStruct.new(options)
        @template = @context.template || 'universal'
        @context.job_name = 'default-job' if @context.job_name.nil?
        @prepare = AlcesJob::Services::Prepare
        @file_path = File.join(Dir.pwd, @context.output_file.nil? ? "job-#{@context.job_name || 'default'}.slurm" : @context.output_file)
      end

      # Generates the script using a template and the options passed in
      # @return [String]
      def generate
        ERB.new(template, trim_mode: '-').result(binding)
      end

      # Saves the script that was passed
      # @param [String] script
      # @return [String]
      def save(script)
        File.write(@file_path, script)

        @file_path
      end

      # Submits the given file to Slurm using `sbatch`
      # @param file_path [String] Path to the job script to submit
      # @return [Array<(String, Process::Status)>]
      def submit(file_path)
        stdout, _, status = Open3.capture3("sbatch #{file_path}")

        [stdout, status]
      end

      private

      # The template to be used to generate the script
      # @return [String]
      def template
        paths = Services::Paths.new

        built_in_path = File.join(__dir__, '../../../templates', "#{@template}.erb")
        user_path = paths.user_template_path(@template.strip)
        admin_file = paths.admin_template_path(@template.strip)

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
