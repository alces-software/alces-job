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
        File.read(File.join(__dir__, '../../templates', "#{@template}.erb"))
      end
    end
  end
end
