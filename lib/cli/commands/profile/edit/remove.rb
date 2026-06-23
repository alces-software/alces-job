# frozen_string_literal: true

require 'dry/cli'
require 'yaml'
require 'pastel'
require 'tty-spinner'

require_relative '../../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class ProfileEditRemove < Dry::CLI::Command
        AlcesJob::CLI.register 'profile edit remove', self
        desc 'This is used to remove flags that have been stored in a profile'

        argument :profile_name, require: true, type: :string, desc: 'The profile you want to update'

        option :job_name, type: :boolean,
                          desc: 'Sets the Slurm job name for the generated script'
        option :nodes, type: :boolean,
                       desc: 'Requests the number of compute nodes for the job'
        option :ntasks, type: :boolean,
                        desc: 'Specifies the total number of tasks for the job'
        option :cpus_per_task, type: :boolean,
                               desc: 'Specifies CPU cores per task'
        option :mem, type: :boolean,
                     desc: 'Sets the memory requirement for the job (e.g. 4G or 2000M)'

        option :time, type: :boolean,
                      desc: 'Sets the job time limit (e.g. 02:00:00)'
        option :partition, type: :boolean,
                           desc: 'Specifies the Slurm partition or queue to use'
        option :account, type: :boolean,
                         desc: 'Specifies the Slurm account to charge'
        option :gres, type: :boolean,
                      desc: 'Specifies generic resources such as GPUs or MICs'

        option :output, type: :boolean,
                        desc: 'Sets the Slurm stdout file path in the generated script'
        option :error, type: :boolean,
                       desc: 'Sets the Slurm stderr file path in the generated script'

        option :mail_user, type: :boolean,
                           desc: 'Sets the email address for Slurm notifications'
        option :mail_type, type: :boolean,
                           desc: 'Sets the Slurm mail notification type (BEGIN, END, FAIL, etc.)'

        option :module, type: :boolean,
                        desc: 'Loads one or more environment modules before running the job'

        option :workdir, type: :boolean,
                         desc: 'Changes to the specified working directory in the job script'
        option :command, type: :boolean,
                         desc: 'Specifies the shell command to execute in the script'
        option :array, type: :boolean,
                       desc: 'Sets a Slurm array specification for multiple jobs'
        option :dependency, type: :boolean,
                            desc: 'Sets a Slurm dependency string for the job'

        def call(profile_name:, **options)
          options.delete(:args)
          pastel = Pastel.new

          if profile_name.nil?
            puts pastel.red("\nNo profile name was provided\n")
            exit(1)
          end

          profile_path = AlcesJob::Paths.new.user_profile_path(profile_name.strip)
          options.select { |_key, value| value }

          if options.empty?
            puts pastel.red("\nNo flags were provided that could be removed from the profile\n")
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

          unless File.exist?(profile_path)
            spinner.error(pastel.red('(no profile)'))

            puts pastel.red("\nNo profile can be found with that name\n")
            exit(1)
          end

          profile_data = YAML.load_file(profile_path)

          spinner.success(pastel.green('(profile loaded)'))
          spinner.update(title: 'updating profile')
          spinner.auto_spin

          options.each_key { |key| profile_data.delete(key.to_sym) }

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
            puts pastel.red("\nFailed to update the profile: #{e.message}\n")
            exit(1)
          end
        end
      end
    end
  end
end
