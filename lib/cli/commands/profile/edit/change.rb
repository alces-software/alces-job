# frozen_string_literal: true

require 'dry/cli'
require 'yaml'
require 'pastel'
require 'tty-spinner'

require_relative '../../../../services/paths/paths'
require_relative '../../../../services/module_extractor/module_extractor'

module AlcesJob
  module CLI
    module Commands
      class ProfileEditChange < Dry::CLI::Command
        AlcesJob::CLI.register 'profile edit change', self

        desc 'Change or add Slurm options within an existing profile.'

        argument :profile_name, required: true, type: :string, desc: 'The profile you want to update'

        option :job_name, type: :string, aliases: ['-J'], desc: 'Sets the Slurm job name for the generated script'
        option :nodes, type: :integer, desc: 'Requests the number of compute nodes for the job'
        option :ntasks, type: :integer, desc: 'Specifies the total number of tasks for the job'
        option :cpus_per_task, type: :integer, desc: 'Specifies CPU cores per task'
        option :mem, type: :string, desc: 'Sets the memory requirement for the job (e.g. 4G or 2000M)'
        option :time, type: :string, aliases: ['-t'], desc: 'Sets the job time limit (e.g. 02:00:00)'
        option :partition, type: :string, aliases: ['-p'], desc: 'Specifies the Slurm partition or queue to use'
        option :account, type: :string, aliases: ['-A'], desc: 'Specifies the Slurm account to charge'
        option :gres, type: :string, desc: 'Specifies generic resources such as GPUs or MICs'
        option :output, type: :string, aliases: ['-o'], desc: 'Sets the Slurm stdout file path in the generated script'
        option :error, type: :string, aliases: ['-e'], desc: 'Sets the Slurm stderr file path in the generated script'
        option :mail_user, type: :string, desc: 'Sets the email address for Slurm notifications'
        option :mail_type, type: :string, desc: 'Sets the Slurm mail notification type (BEGIN, END, FAIL, etc.)'
        option :module, type: :array, aliases: ['-m'], default: [], desc: 'Loads one or more environment modules before running the job'
        option :workdir, type: :string, desc: 'Changes to the specified working directory in the job script'
        option :command, type: :string, desc: 'Specifies the shell command to execute in the script'
        option :array, type: :string, desc: 'Sets a Slurm array specification for multiple jobs'
        option :dependency, type: :string, desc: 'Sets a Slurm dependency string for the job'

        def call(profile_name:, **options)
          options[:module] = AlcesJob::Services.module_extractor(ARGV)
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
          options.reject! { |_, value| value == [] }

          if options.empty?
            warn pastel.red("\nNo profile settings were provided to update.")
            warn pastel.yellow("Specify one or more command-line options to modify the profile.\n")
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
            warn pastel.red("\nYou do not have permission to read this profile.\n")
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to load profile)'))
            warn pastel.red("\nFailed to load the profile.")
            warn pastel.yellow('The profile may contain invalid YAML or be corrupted.')
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Profile loaded)'))
          spinner.update(title: 'updating profile')
          spinner.auto_spin

          # ------------------------------------------------------------
          # Update profile
          # ------------------------------------------------------------
          begin
            profile_data = profile_data.merge(options)
          rescue StandardError => e
            spinner.error(pastel.red('(Update failed)'))
            warn pastel.red("\nFailed to update the profile.")
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
