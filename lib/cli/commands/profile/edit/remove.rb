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

        desc 'Remove stored Slurm options from an existing profile.'

        argument :profile_name, required: true, type: :string, desc: 'The profile you want to update'

        option :job_name, type: :boolean, aliases: ['-J'], desc: 'Remove the Slurm job name'
        option :nodes, type: :boolean, desc: 'Remove the node count'
        option :ntasks, type: :boolean, desc: 'Remove the task count'
        option :cpus_per_task, type: :boolean, desc: 'Remove CPUs per task'
        option :mem, type: :boolean, desc: 'Remove the memory requirement'
        option :time, type: :boolean, aliases: ['-t'], desc: 'Remove the time limit'
        option :partition, type: :boolean, aliases: ['-p'], desc: 'Remove the partition'
        option :account, type: :boolean, aliases: ['-A'], desc: 'Remove the account'
        option :gres, type: :boolean, desc: 'Remove generic resource requirements'
        option :output, type: :boolean, aliases: ['-o'], desc: 'Remove the output file path'
        option :error, type: :boolean, aliases: ['-e'], desc: 'Remove the error file path'
        option :mail_user, type: :boolean, desc: 'Remove the mail user'
        option :mail_type, type: :boolean, desc: 'Remove the mail notification type'
        option :module, type: :boolean, aliases: ['-m'], desc: 'Remove loaded modules'
        option :workdir, type: :boolean, desc: 'Remove the working directory'
        option :command, type: :boolean, desc: 'Remove the command'
        option :array, type: :boolean, desc: 'Remove the array specification'
        option :dependency, type: :boolean, desc: 'Remove the dependency'

        def call(profile_name:, **options)
          options.delete(:args)

          pastel = Pastel.new

          # ------------------------------------------------------------
          # Validate input
          # ------------------------------------------------------------
          if profile_name.to_s.strip.empty?
            warn pastel.red("\nNo profile name was provided.")
            warn pastel.yellow("Please specify the name of the profile you want to update.\n")
            exit(1)
          end

          profile_path = Services::Paths.new.user_profile_path(profile_name.strip)

          # ------------------------------------------------------------
          # Validate options
          # ------------------------------------------------------------
          options.select! { |_key, value| value }

          if options.empty?
            warn pastel.red("\nNo profile settings were provided to remove.")
            warn pastel.yellow("Specify one or more command-line options to remove from the profile.\n")
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

          # ------------------------------------------------------------
          # Check profile exists
          # ------------------------------------------------------------
          begin
            unless File.exist?(profile_path)
              spinner.error(pastel.red('(Profile not found)'))
              warn pastel.red("\nProfile not found: #{profile_name}")
              warn pastel.yellow("Check the profile name and try again.\n")
              exit(1)
            end
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to check profile)'))
            warn pastel.red("\nFailed to check whether the profile exists.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Load profile
          # ------------------------------------------------------------
          begin
            profile_data = YAML.load_file(profile_path)
          rescue Errno::ENOENT
            spinner.error(pastel.red('(Profile missing)'))
            warn pastel.red("\nThe profile file could not be found.")
            warn pastel.yellow("It may have been moved or deleted.\n")
            exit(1)
          rescue Errno::EACCES
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red("\nYou do not have permission to read this profile.")
            exit(1)
          rescue Psych::SyntaxError => e
            spinner.error(pastel.red('(Invalid YAML)'))
            warn pastel.red("\nThe profile contains invalid YAML.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to load profile)'))
            warn pastel.red("\nFailed to load the profile.")
            warn pastel.yellow('The profile may be corrupted or unreadable.')
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Profile loaded)'))
          spinner.update(title: 'removing settings')
          spinner.auto_spin

          # ------------------------------------------------------------
          # Remove selected settings
          # ------------------------------------------------------------
          begin
            options.each_key { |key| profile_data.delete(key.to_sym) }
          rescue StandardError => e
            spinner.error(pastel.red('(Removal failed)'))
            warn pastel.red("\nFailed to remove the selected settings from the profile.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Updated)'))
          spinner.update(title: 'writing profile')
          spinner.auto_spin

          # ------------------------------------------------------------
          # Save profile
          # ------------------------------------------------------------
          begin
            File.write(profile_path, profile_data.to_yaml)

            spinner.success(pastel.green('(Written)'))

            puts pastel.green("\nProfile updated successfully.\n")
            exit(0)
          rescue Errno::ENOSPC
            spinner.error(pastel.red('(Disk full)'))
            warn pastel.red("\nThere is not enough disk space to save the profile.\n")
            exit(1)
          rescue Errno::ENOENT, Errno::ENOTDIR
            spinner.error(pastel.red('(Invalid path)'))
            warn pastel.red("\nThe profile path does not exist or is invalid.\n")
            exit(1)
          rescue Errno::EACCES, Errno::EROFS
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red("\nYou do not have permission to write to this profile.\n")
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Write failed)'))
            warn pastel.red("\nFailed to save the updated profile.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          spinner&.error(pastel.red('(Unexpected error)'))
          warn pastel.red("\nAn unexpected error occurred while updating the profile.")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
