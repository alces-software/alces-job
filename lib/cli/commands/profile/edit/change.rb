# frozen_string_literal: true

require 'dry/cli'
require 'yaml'
require 'pastel'
require 'tty-spinner'

require_relative '../../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class ProfileEditChange < Dry::CLI::Command
        AlcesJob::CLI.register 'profile edit change', self
        desc 'This is used to change and add flags within the the specified profile'

        argument :profile_name, require: true, type: :string, desc: 'The profile you want to update'

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

          if profile_name.to_s.strip.empty?
            puts pastel.red("\nNo profile name was provided\n")
            exit(1)
          end

          profile_path = Services::Paths.new.user_profile_path(profile_name.strip)
          options.reject! { |_, value| value == [] }

          if options.empty?
            puts pastel.red("\nNo flags were provided that could be added or changed in the profile\n")
            exit(1)
          end

          puts
          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )
          spinner.update(title: 'loading profile')
          spinner.auto_spin

          begin
            unless File.exist?(profile_path)
              spinner.error(pastel.red('(no profile)'))
              puts pastel.red("\nNo profile can be found with that name\n")
              exit(1)
            end
          rescue StandardError => e
            spinner.error('(failed to check profile)')
            puts pastel.red("\nFailed to check if the profile exists:\n#{e.message}\n")
            exit(1)
          end

          begin
            profile_data = YAML.load_file(profile_path)
          rescue StandardError => e
            spinner.error('(failed to load profile)')
            puts pastel.red("\nFailed to load profile:\n#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(profile loaded)'))
          spinner.update(title: 'updating profile')
          spinner.auto_spin

          begin
            profile_data = profile_data.merge(options)
          rescue StandardError => e
            spinner.error('(failed to update)')
            puts pastel.red("\nFailed to update the profile information:\n#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(successful)'))
          spinner.update(title: 'writing to file')
          spinner.auto_spin

          begin
            File.write(profile_path, profile_data.to_yaml)
            spinner.success(pastel.green('(written)'))
            puts pastel.green("\nSuccessfully updated the profile\n")
            exit(0)
          rescue StandardError => e
            spinner.error(pastel.red('(write error)'))
            puts pastel.red("\nFailed to update the profile:\n#{e.message}\n")
            exit(1)
          end
        rescue StandardError => e
          spinner&.error('(command error)')
          puts pastel.red("\nAn error occurred while running the command:\n#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
