# frozen_string_literal: true

require 'dry/cli'
require_relative '../../services/generator'

module AlcesJob
  module CLI
    module Commands
      class Array < Dry::CLI::Command
        option :job_name, type: :string
        option :nodes, type: :integer
        option :mem, type: :string

        option :time, type: :string
        option :partition, type: :string

        option :module, type: :array, default: []

        option :workdir, type: :string
        option :command, type: :string
        option :array, type: :string

        option :output_file, type: :string

        AlcesJob::CLI.register 'array', self
        desc 'Creates an array sbatch script'

        def call(**options)
          if options[:array].nil? || options[:array].to_s.strip.empty?
            warn 'Error: --array is required for array jobs'
            exit(1)
          end

          options[:template] = 'array'

          generator = AlcesJob::Services::Generator.new(options)
          generator.generate
          generator.save
        end
      end
    end
  end
end
