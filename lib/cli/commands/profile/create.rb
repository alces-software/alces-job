# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'
require 'fileutils'

require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class ProfileCreate < Dry::CLI::Command
        AlcesJob::CLI.register 'profile create', self
        desc 'This command creates a profile bases on the flags passed in'

        argument :profile_name, require: true, type: :string, desc: 'What the profile will be called'

        option :job_name, type: :string,
                          desc: 'Sets the Slurm job name for the generated script'

        option :nodes, type: :integer,
                       desc: 'Requests the number of compute nodes for the job'

        option :ntasks, type: :integer,
                        desc: 'Specifies the total number of tasks for the job'

        option :cpus_per_task, type: :integer,
                               desc: 'Specifies CPU cores per task'

        option :mem, type: :string,
                     desc: 'Sets the memory requirement for the job (e.g. 4G or 2000M)'

        option :time, type: :string,
                      desc: 'Sets the job time limit (e.g. 02:00:00)'

        option :partition, type: :string,
                           desc: 'Specifies the Slurm partition or queue to use'

        option :account, type: :string,
                         desc: 'Specifies the Slurm account to charge'

        option :gres, type: :string,
                      desc: 'Specifies generic resources such as GPUs or MICs'

        option :output, type: :string,
                        desc: 'Sets the Slurm stdout file path in the generated script'

        option :error, type: :string,
                       desc: 'Sets the Slurm stderr file path in the generated script'

        option :mail_user, type: :string,
                           desc: 'Sets the email address for Slurm notifications'

        option :mail_type, type: :string,
                           desc: 'Sets the Slurm mail notification type (BEGIN, END, FAIL, etc.)'

        option :module, type: :array, default: [],
                        desc: 'Loads one or more environment modules before running the job'

        option :workdir, type: :string,
                         desc: 'Changes to the specified working directory in the job script'

        option :command, type: :string,
                         desc: 'Specifies the shell command to execute in the script'

        option :array, type: :string,
                       desc: 'Sets a Slurm array specification for multiple jobs'

        option :dependency, type: :string,
                            desc: 'Sets a Slurm dependency string for the job'

        def call(profile_name:, **options)
          options.delete(:args)
          pastel = Pastel.new
          prompt = TTY::Prompt.new

          if name.to_s.strip.empty?
            puts pastel.red("\nNo profile name was provided\n")
            exit(1)
          end

          profile_path = Services::Paths.new.user_profile_path(profile_name.strip)
          options.reject! { |_, value| value == [] }

          if options.empty?
            puts pastel.red("\nNo flags were provided that could be saved to a profile\n")
            exit(1)
          end

          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )
          spinner.update(title: 'generating profile')
          spinner.auto_spin

          if File.exist?(profile_path)
            spinner.error(pastel.red('(profile exists)'))

            exit(0) unless prompt.yes?("\nA profile with that name was found do you want to overwrite it?", default: false)

            puts
            spinner.update(title: 'overwriting profile')
            spinner.auto_spin
          end

          begin
            FileUtils.mkdir_p(File.dirname(profile_path))
            File.write(profile_path, options.to_yaml)
            spinner.success(pastel.green('(successful)'))

            puts pastel.green("\nYour profile has been created and written to #{profile_path}\n")
            exit(0)
          rescue StandardError => e
            spinner.error(pastel.red('(writing error)'))
            puts pastel.green("\nFailed to create your profile: #{e.message}\n")
            exit(1)
          end
        end
      end
    end
  end
end
