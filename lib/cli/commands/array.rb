# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'

require_relative '../../services/generator'

module AlcesJob
  module CLI
    module Commands
      class Array < Dry::CLI::Command
        option :job_name, type: :string,
                          desc: 'Sets the Slurm job name for the generated array script'
        option :nodes, type: :integer,
                       desc: 'Requests the number of compute nodes for the array job'
        option :mem, type: :string,
                     desc: 'Sets the memory requirement for the job (e.g. 4G or 2000M)'

        option :time, type: :string,
                      desc: 'Sets the walltime limit for the array job'
        option :partition, type: :string,
                           desc: 'Specifies the Slurm partition or queue to use'

        option :module, type: :array, default: [],
                        desc: 'Loads environment modules before running the job'

        option :workdir, type: :string,
                         desc: 'Changes to the specified working directory in the job script'
        option :command, type: :string,
                         desc: 'Specifies the shell command to execute in the script'
        option :array, type: :string,
                       desc: 'Sets the Slurm array task specification for the job'

        option :output_file, type: :string,
                             desc: 'Writes the generated script to this filename instead of job.sbatch'

        option :submit, type: :boolean, default: false,
                        desc: 'Makes it so the SBATCH script that is generated is submitted to slurm automatically'

        option :profile, type: :string, desc: 'The name of a profile you have stored to load predetermined flags'

        option :dry_run, type: :boolean, default: false,
                         desc: 'Does not save the file if set to true'

        AlcesJob::CLI.register 'array', self
        desc 'Creates an array sbatch script'

        def call(**options)
          pastel = Pastel.new

          unless options[:profile].nil?
            config = YAML.load_file(File.expand_path('../../../config/config.yaml', __dir__))
            profile = YAML.load_file("#{config['user_profile_dir']}/#{options[:profile]}.yaml")

            options.delete(:profile)

            options = profile.merge(options)
          end

          # Generate sbatch file bases on user inputs
          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.update(title: 'generating SBATCH script')
          spinner.auto_spin

          if options[:array].nil? || options[:array].to_s.strip.empty?
            warn 'Error: --array is required for array jobs'
            exit(1)
          end

          options[:template] = 'array'

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

            puts "\n#{stdout}\n"
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
