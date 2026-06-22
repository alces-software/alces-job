# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'

require_relative '../../services/generator'

module AlcesJob
  module CLI
    module Commands
      class MPI < Dry::CLI::Command
        AlcesJob::CLI.register 'mpi', self
        desc 'Creates a MPI sbatch script'

        option :job_name, type: :string, aliases: ['-J'],
                          desc: 'Sets the Slurm job name for the generated MPI script'
        option :nodes, type: :integer, aliases: ['-N'],
                       desc: 'Requests the number of compute nodes for the MPI job'
        option :ntasks, type: :integer, aliases: ['-n'],
                        desc: 'Specifies the total number of MPI tasks'
        option :cpus_per_task, type: :integer, aliases: ['-c'],
                               desc: 'Specifies CPU cores per task'
        option :mem, type: :string,
                     desc: 'Sets the memory requirement for the job (e.g. 4G or 2000M)'

        option :time, type: :string, aliases: ['-t'],
                      desc: 'Sets the walltime limit for the MPI job'
        option :partition, type: :string, aliases: ['-p'],
                           desc: 'Specifies the Slurm partition or queue to use'

        option :module, type: :array, default: [],
                        desc: 'Loads environment modules before running the job'

        option :workdir, type: :string,
                         desc: 'Changes to the specified working directory in the job script'
        option :command, type: :string,
                         desc: 'Specifies the shell command to execute in the script'

        option :output_file, type: :string, aliases: ['-o'],
                             desc: 'Writes the generated script to this filename instead of job.sbatch'

        option :submit, type: :boolean, default: false,
                        desc: 'Makes it so the SBATCH script that is generated is submitted to slurm automatically'

        option :site_config, type: :boolean, default: true, desc: 'whether or not to use the admins specified config file'

        option :yes, type: :boolean, default: false,
                     desc: 'Submits the generated script without prompting'

        option :profile, type: :string, desc: 'The name of a profile you have stored to load predetermined flags'

        option :dry_run, type: :boolean, default: false,
                         desc: 'Does not save the file if set to true'

        def call(**options)
          pastel = Pastel.new
          config = YAML.load_file(File.expand_path('../../../config/config.yaml', __dir__))

          if options[:site_config]
            admin_path = config['admin_config_file']
            if File.exist?(admin_path)
              admin = YAML.load_file(admin_path)
              admin_keys = admin.keys
              puts
              options.each_key do |key|
                if admin_keys.include?(key)
                  puts pastel.yellow("You are overwriting the system admin defined #{key}")
                else
                  puts pastel.green("Admin defined #{key} loaded")
                end
              end

              options = admin.merge(options)
            end
          end

          unless options[:profile].nil?
            profile_path = File.join(config['user_profile_dir'], "#{options[:profile]}.yaml")
            options.delete(:profile)
            if File.exist?(profile_path)
              profile = YAML.load_file(profile_path)
              options_keys = options.keys
              puts
              profile.keys.each_key do |key|
                if options_keys.include?(key)
                  puts pastel.yellow("Ignoring profile flag #{key}")
                else
                  puts pastel.green("Loaded profile flag #{key}")
                end
              end

              options = profile.merge(options)
            end
          end

          # Generate sbatch file bases on user flags
          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.update(title: 'generating SBATCH script')
          spinner.auto_spin

          options[:template] = 'mpi'

          generator = AlcesJob::Services::Generator.new(options)
          if options[:dry_run].nil? || !options[:dry_run]
            if File.exist?(generator.file_path)
              spinner.error(pastel.red('(file exists)'))
              exit(0) unless TTY::Prompt.new.yes?("\nAn sbatch already exists do you want to overwrite it?", default: false)

              puts
              spinner.update(title: 'Overwriting SBATCH script')
              spinner.auto_spin
            end

            file_path = generator.save

            spinner.success(pastel.green('(successful)'))

            puts pastel.green("\nThe SBTACH script has been generated and saved to #{file_path}\n")

            # Submit the sbatch file to sbatch if user adds submit flag
            exit(0) unless options[:submit]

            unless options[:yes] || TTY::Prompt.new.yes?("\nWould you like to submit this script?", default: false)
              puts pastel.yellow("\nSkipping submission\n")
              exit(0)
            end

            spinner.update(title: 'submitting script')
            spinner.auto_spin

            stdout, status = generator.submit(file_path)

            unless status.success?
              spinner.error(pastel.red('(error)'))
              puts pastel.red("\nAn error occurred\n")
              exit(1)
            end

            spinner.success(pastel.green('(submitted)'))

            puts "\n#{stdout}\n"
          else
            output = generator.generate

            spinner.success(pastel.green('(successful)'))

            puts pastel.green("\nThe SBTACH script has been generated and looks as follows:")
            puts output
          end
          exit(0)
        rescue Errno::ENOENT
          spinner.error(pastel.red('(error)'))
          puts pastel.red("\nAn error occurred\n")
          exit(1)
        end
      end
    end
  end
end
