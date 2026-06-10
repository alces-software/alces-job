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
          pastel = Pastel.new

          # Generate sbatch file
          spinner = TTY::Spinner.new(
            "\n[:spinner] generating SBATCH script ...",
            success_mark: pastel.green('✔'),
            error_mark: pastel.red('✖')
          )

          spinner.auto_spin

          if options[:array].nil? || options[:array].to_s.strip.empty?
            warn 'Error: --array is required for array jobs'
            exit(1)
          end

          options[:template] = 'array'

          generator = AlcesJob::Services::Generator.new(options)
          file_path = generator.save

          spinner.success('(successful)')

          puts pastel.green("The SBTACH script has been generated and saved to #{file_path}\n")

          # Submit the sbatch file to sbatch if user adds flag
          return unless options[:submit]

          spinner = TTY::Spinner.new(
            '[:spinner] submitting script ...',
            success_mark: pastel.green('✔'),
            error_mark: pastel.red('✖')
          )

          spinner.auto_spin
          stdout, _, status = Open3.capture3("sbatch #{file_path}")

          unless status.success?
            spinner.error('(error)')
            puts pastel.red("An error occurred\n")
            return
          end

          spinner.success('(submitted)')

          puts "#{stdout}\n"
        rescue Errno::ENOENT
          spinner.error('(error)')
          puts pastel.red("An error occurred\n")
        end
      end
    end
  end
end
