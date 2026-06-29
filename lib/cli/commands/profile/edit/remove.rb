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

        option :job_name, type: :boolean, aliases: ['-J'], desc: 'Sets the Slurm job name for the generated script'
        option :nodes, type: :boolean, desc: 'Requests the number of compute nodes for the job'
        option :ntasks, type: :boolean, desc: 'Specifies the total number of tasks for the job'
        option :cpus_per_task, type: :boolean, desc: 'Specifies CPU cores per task'
        option :mem, type: :boolean, desc: 'Sets the memory requirement for the job (e.g. 4G or 2000M)'
        option :time, type: :boolean, aliases: ['-t'], desc: 'Sets the job time limit (e.g. 02:00:00)'
        option :partition, type: :boolean, aliases: ['-p'], desc: 'Specifies the Slurm partition or queue to use'
        option :account, type: :boolean, aliases: ['-A'], desc: 'Specifies the Slurm account to charge'
        option :gres, type: :boolean, desc: 'Specifies generic resources such as GPUs or MICs'
        option :output, type: :boolean, aliases: ['-o'], desc: 'Sets the Slurm stdout file path in the generated script'
        option :error, type: :boolean, aliases: ['-e'], desc: 'Sets the Slurm stderr file path in the generated script'
        option :mail_user, type: :boolean, desc: 'Sets the email address for Slurm notifications'
        option :mail_type, type: :boolean, desc: 'Sets the Slurm mail notification type (BEGIN, END, FAIL, etc.)'
        option :module, type: :boolean, aliases: ['-m'], desc: 'Loads one or more environment modules before running the job'
        option :workdir, type: :boolean, desc: 'Changes to the specified working directory in the job script'
        option :command, type: :boolean, desc: 'Specifies the shell command to execute in the script'
        option :array, type: :boolean, desc: 'Sets a Slurm array specification for multiple jobs'
        option :dependency, type: :boolean, desc: 'Sets a Slurm dependency string for the job'

        def call(profile_name:, **options)
          options.delete(:args)
          pastel = Pastel.new

          if profile_name.to_s.strip.empty?
            puts pastel.red("\nNo profile name was provided.\n")
            exit(1)
          end

          profile_path = Services::Paths.new.user_profile_path(profile_name.strip)
          options.select { |_key, value| value }

          if options.empty?
            puts pastel.red("\nNo flags were provided that could be removed from the profile.\n")
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
              spinner.error(pastel.red('(No profile)'))
              puts pastel.red("\nNo profile can be found with that name.\n")
              exit(1)
            end
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to check profile)'))
            puts pastel.red("\nFailed to check if the profile exists:\n#{e.message}\n")
            exit(1)
          end

          begin
            profile_data = YAML.load_file(profile_path)
          rescue Errno::ENOENT
            spinner.error(pastel.red('(Profile missing)'))
            puts pastel.red("\nThe profile file could not be found. \n")
            exit(1)
          rescue Errno::EACCES
            spinner.error(pastel.red('(Permission denied)'))
            puts pastel.red("\nYou do not have permission to read this profile. \n")
            exit(1)
          rescue Psych::SyntaxError => e
            spinner.error(pastel.red('Invalid YAML:'))
            puts pastel.red("\nThe profile contains invalid YAML:\n#{e.message}\n")
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to load profile)'))
            puts pastel.red("\nFailed to load profile:\n#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Profile loaded)'))
          spinner.update(title: 'updating profile')
          spinner.auto_spin

          begin
            options.each_key { |key| profile_data.delete(key.to_sym) }
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to remove flags)'))
            puts pastel.red("\nFailed to remove flags from the profile:\n#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Successful)'))
          spinner.update(title: 'writing to file')
          spinner.auto_spin

          begin
            File.write(profile_path, profile_data.to_yaml)
            spinner.success(pastel.green('(Written)'))
            puts pastel.green("\nSuccessfully updated the profile\n")
            exit(0)
          rescue StandardError => e
            spinner.error(pastel.red('(Write error)'))
            puts pastel.red("\nFailed to update the profile:\n#{e.message}\n")
            exit(1)
          end
        rescue StandardError => e
          spinner&.error(pastel.red('(Command error)'))
          puts pastel.red("\nAn error occurred while running the command:\n#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
