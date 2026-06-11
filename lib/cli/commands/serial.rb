# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'

require_relative '../../services/generator'

module AlcesJob
  module CLI
    module Commands
      class Serial < Dry::CLI::Command
        option :job_name, type: :string
        option :mem, type: :string

        option :time, type: :string
        option :partition, type: :string

        option :module, type: :array, default: []

        option :workdir, type: :string
        option :command, type: :string

        option :output_file, type: :string

        option :submit, type: :boolean, default: false,
                        desc: 'Makes it so the SBATCH script that is generated is submitted to slurm automatically'

        AlcesJob::CLI.register 'serial', self
        desc 'Creates a serial sbatch script'

        def call(**options)
          pastel = Pastel.new

          # Generate sbatch file bases on user flags
          spinner = TTY::Spinner.new(
            "\n[:spinner] generating SBATCH script ...",
            success_mark: pastel.green('✔'),
            error_mark: pastel.red('✖')
          )

          spinner.auto_spin

          options[:template] = 'serial'

          generator = AlcesJob::Services::Generator.new(options)
          file_path = generator.save

          spinner.success('(successful)')

          puts pastel.green("The SBTACH script has been generated and saved to #{file_path}\n")

          # Submit the sbatch file to sbatch if user adds submit flag
          return unless options[:submit]

          spinner = TTY::Spinner.new(
            '[:spinner] submitting script ...',
            success_mark: pastel.green('✔'),
            error_mark: pastel.red('✖')
          )

          spinner.auto_spin

          stdout, status = generator.submit(file_path)

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
