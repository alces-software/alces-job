# frozen_string_literal: true

require 'dry/cli'

require_relative '../../services/generator'

module AlcesJob
  module CLI
    module Commands
      class Default < Dry::CLI::Command
        option :job_name, type: :string
        option :nodes, type: :integer
        option :ntasks, type: :integer
        option :cpus_per_task, type: :integer
        option :mem, type: :string

        option :time, type: :string
        option :partition, type: :string
        option :account, type: :string
        option :gres, type: :string

        option :output, type: :string
        option :error, type: :string

        option :mail_user, type: :string
        option :mail_type, type: :string

        option :module, type: :array, default: []

        option :workdir, type: :string
        option :command, type: :string
        option :array, type: :string
        option :dependency, type: :string

        option :output_file, type: :string

        AlcesJob::CLI.register 'default', self
        desc 'tmp'

        def call(*_args, **options)
          generator = AlcesJob::Services::Generator.new(options)
          generator.save
        end
      end
    end
  end
end
