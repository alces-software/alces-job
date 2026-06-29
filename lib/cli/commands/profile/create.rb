# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'
require 'fileutils'

require_relative '../../../services/paths/paths'
require_relative '../../../services/module_extractor/module_extractor'

module AlcesJob
  module CLI
    module Commands
      class ProfileCreate < Dry::CLI::Command
        AlcesJob::CLI.register 'profile create', self

        desc 'Create a new profile using the supplied Slurm options.'

        argument :profile_name, required: true, type: :string, desc: 'The name of the profile to create'

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
          prompt = TTY::Prompt.new
          path = Services::Paths.new

          # ------------------------------------------------------------
          # Validate input
          # ------------------------------------------------------------
          if profile_name.to_s.strip.empty?
            warn pastel.red('No profile name was provided.')
            warn pastel.yellow('Please specify a name for the profile.')
            exit(1)
          end

          profile_path = path.user_profile_path(profile_name.strip)

          # ------------------------------------------------------------
          # Validate options
          # ------------------------------------------------------------
          options.reject! { |_, value| value == [] }

          if options.empty?
            warn pastel.red('No profile settings were provided.')
            warn pastel.yellow('Specify one or more command-line options to save in the profile.')
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

          # ------------------------------------------------------------
          # Check whether the profile already exists
          # ------------------------------------------------------------
          begin
            if File.exist?(profile_path)
              spinner.error(pastel.red('(Profile exists)'))

              overwrite = prompt.yes?(
                "\nA profile named '#{profile_name}' already exists. Do you want to overwrite it?",
                default: false
              )

              unless overwrite
                warn pastel.yellow('Profile creation cancelled.')
                exit(0)
              end

              puts
              spinner.update(title: 'overwriting profile')
              spinner.auto_spin
            end
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to check profile)'))
            warn pastel.red('Failed to check whether the profile already exists.')
            warn pastel.red(e.message)
            exit(1)
          end

          # ------------------------------------------------------------
          # Create profile directory and save profile
          # ------------------------------------------------------------
          begin
            FileUtils.mkdir_p(path.user_profile_dir)
            File.write(profile_path, options.to_yaml)

            spinner.success(pastel.green('(Created)'))

            puts pastel.green("\nProfile created successfully.")
            puts pastel.green("Written to: #{profile_path}\n")

            exit(0)
          rescue Errno::ENOSPC
            spinner.error(pastel.red('(Disk full)'))
            warn pastel.red('There is not enough disk space to create the profile.')
            exit(1)
          rescue Errno::EACCES, Errno::EROFS
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red('You do not have permission to create the profile in this location.')
            exit(1)
          rescue Errno::ENOENT, Errno::ENOTDIR
            spinner.error(pastel.red('(Invalid path)'))
            warn pastel.red('The profile directory does not exist or is invalid.')
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Write failed)'))
            warn pastel.red('Failed to create the profile.')
            warn pastel.red(e.message)
            exit(1)
          end
        rescue StandardError => e
          spinner&.error(pastel.red('(Unexpected error)'))
          warn pastel.red('An unexpected error occurred while creating the profile.')
          warn pastel.red(e.message)
          exit(1)
        end
      end
    end
  end
end
