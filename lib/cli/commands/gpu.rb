# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'open3'

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

        option :submit, type: :boolean, default: false,
                        desc: 'Makes it so the SBATCH script that is generated is submitted to slurm automatically'

        AlcesJob::CLI.register 'gpu', self
        desc 'Creates a GPU sbatch script'

        def call(**options)
          pastel = Pastel.new

          # Generate sbatch file
          spinner = TTY::Spinner.new(
            "\n[:spinner] generating SBATCH script ...",
            success_mark: pastel.green('✔'),
            error_mark: pastel.red('✖')
          )

          spinner.auto_spin

          options[:template] = 'gpu'

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
