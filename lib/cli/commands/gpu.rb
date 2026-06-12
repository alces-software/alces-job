# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'

require_relative '../../services/generator'

module AlcesJob
  module CLI
    module Commands
      class GPU < Dry::CLI::Command
        option :job_name, type: :string,
                          desc: 'Sets the Slurm job name for the generated GPU script'
        option :nodes, type: :integer,
                       desc: 'Requests the number of compute nodes for the job'
        option :ntasks, type: :integer,
                        desc: 'Specifies the total number of tasks for the CUDA/GPU job'
        option :cpus_per_task, type: :integer,
                               desc: 'Specifies CPU cores per task'
        option :mem, type: :string,
                     desc: 'Sets the memory requirement for the job (e.g. 4G or 2000M)'

        option :time, type: :string,
                      desc: 'Sets the walltime limit for the job'
        option :partition, type: :string,
                           desc: 'Specifies the Slurm partition or queue to use'
        option :gres, type: :string,
                      desc: 'Specifies generic resources such as GPUs'

        option :module, type: :array, default: [],
                        desc: 'Loads environment modules before running the job'

        option :workdir, type: :string,
                         desc: 'Changes to the specified working directory in the job script'
        option :command, type: :string,
                         desc: 'Specifies the shell command to execute in the script'

        option :output_file, type: :string,
                             desc: 'Writes the generated script to this filename instead of job.sbatch'

        option :submit, type: :boolean, default: false,
                        desc: 'Makes it so the SBATCH script that is generated is submitted to slurm automatically'

        option :profile, type: :string, desc: 'The name of a profile you have stored to load predetermined flags'

        AlcesJob::CLI.register 'gpu', self
        desc 'Creates a GPU sbatch script'

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
            success_mark: pastel.green('✔'),
            error_mark: pastel.red('✖')
          )

          spinner.updater(title: 'generating SBATCH script')
          spinner.auto_spin

          options[:template] = 'gpu'

          generator = AlcesJob::Services::Generator.new(options)
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
