# frozen_string_literal: true

require 'erb'
require 'ostruct'

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
      end

      private

      def template 
        built_in_path = File.join(__dir__, '../../templates', "#{@template}.erb")
        user_path = File.join(File.expand_path('~/.alces-job/templates'), "#{@template}.erb")

        if File.exist?(built_in_path)
          File.read(built_in_path)
        elsif File.exist?(user_path)
          File.read(user_path)
        else
          raise "Template #{@template} not found in built-in or user templates"
        end
    end
  end
end

end

