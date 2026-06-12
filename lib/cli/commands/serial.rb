# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'

require_relative '../../services/generator'

module AlcesJob
  module CLI
    module Commands
      class Serial < Dry::CLI::Command
        AlcesJob::CLI.register 'serial', self
        desc 'Creates a serial sbatch script'

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

        option :dry_run, type: :boolean, default: false,
                         desc: 'Does not save the file if set to true'

        def call(**options)
          pastel = Pastel.new

          # Generate sbatch file bases on user flags
          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.update(title: 'generating SBATCH script')
          spinner.auto_spin

          options[:template] = 'serial'

          generator = AlcesJob::Services::Generator.new(options)
          if options[:dry_run].nil? || !options[:dry_run]
            if File.exist?(generator.file_path)
              spinner.error('(file exists)')
              exit(0) unless TTY::Prompt.new.yes?("\nAn sbatch already exists do you want to overwrite it?", default: false)

              puts
              spinner.update(title: 'Overwriting SBATCH script')
              spinner.auto_spin
            end

            file_path = generator.save

            spinner.success('(successful)')

            puts pastel.green("\nThe SBTACH script has been generated and saved to #{file_path}\n")

            # Submit the sbatch file to sbatch if user adds submit flag
            exit(0) unless options[:submit]

            spinner.update(title: 'submitting script')
            spinner.auto_spin

            stdout, status = generator.submit(file_path)

            unless status.success?
              spinner.error('(error)')
              puts pastel.red("\nAn error occurred\n")
              exit(1)
            end

            spinner.success('(submitted)')

            puts "#{stdout}\n"
          else
            output = generator.generate

            spinner.success('(successful)')

            puts pastel.green("\nThe SBTACH script has been generated and looks as follows:")
            puts output
          end
          exit(0)
        rescue Errno::ENOENT
          spinner.error('(error)')
          puts pastel.red("\nAn error occurred\n")
          exit(1)
        end
      end
    end
  end
end
