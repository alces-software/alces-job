# frozen_string_literal: true

require 'dry/cli'
require_relative '../../services/generator'

module AlcesJob
  module CLI
    module Commands
      class GPU < Dry::CLI::Command
        option :job_name, type: :string
        option :nodes, type: :integer
        option :ntasks, type: :integer
        option :cpus_per_task, type: :integer
        option :mem, type: :string

        option :time, type: :string
        option :partition, type: :string
        option :gres, type: :string

        option :module, type: :array, default: []

        option :workdir, type: :string
        option :command, type: :string

        option :output_file, type: :string

        AlcesJob::CLI.register 'gpu', self
        desc 'Creates a GPU sbatch script'

        def call(**options)
          options[:template] = 'gpu'
          generator = AlcesJob::Services::Generator.new(options)
          generator.generate
          generator.save
        end
      end
    end
  end
end
