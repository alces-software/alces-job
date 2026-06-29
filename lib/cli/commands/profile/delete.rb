# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'

require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class ProfileDelete < Dry::CLI::Command
        AlcesJob::CLI.register 'profile delete', self

        desc 'Delete a saved profile.'

        argument :profile_name, required: true, type: :string, desc: 'The name of the profile to delete'

        def call(profile_name:, **)
          pastel = Pastel.new
          prompt = TTY::Prompt.new

          # ------------------------------------------------------------
          # Validate input
          # ------------------------------------------------------------
          if profile_name.to_s.strip.empty?
            warn pastel.red('No profile name was provided.')
            warn pastel.yellow('Please specify the name of the profile you want to delete.')
            exit(1)
          end

          profile_name = profile_name.strip
          profile_path = Services::Paths.new.user_profile_path(profile_name)

          # ------------------------------------------------------------
          # Check profile exists
          # ------------------------------------------------------------
          begin
            unless File.exist?(profile_path)
              warn pastel.red("Profile not found: #{profile_name}")
              warn pastel.yellow('Check the profile name and try again.')
              exit(1)
            end
          rescue StandardError => e
            warn pastel.red('Failed to check whether the profile exists.')
            warn pastel.red(e.message)
            exit(1)
          end

          # ------------------------------------------------------------
          # Confirm deletion
          # ------------------------------------------------------------
          unless prompt.yes?(
            "Are you sure you want to delete the '#{profile_name}' profile?",
            default: false
          )
            warn pastel.yellow('Profile deletion cancelled.')
            exit(0)
          end

          puts

          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.update(title: 'deleting profile')
          spinner.auto_spin

          # ------------------------------------------------------------
          # Delete profile
          # ------------------------------------------------------------
          begin
            File.unlink(profile_path)

            spinner.success(pastel.green('(Deleted)'))

            puts pastel.green("\nProfile deleted successfully.\n")
            exit(0)
          rescue Errno::ENOENT
            spinner.error(pastel.red('(Profile missing)'))
            warn pastel.red('The profile could not be found when deletion was attempted.')
            exit(1)
          rescue Errno::EACCES, Errno::EROFS
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red('You do not have permission to delete this profile.')
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Delete failed)'))
            warn pastel.red('Failed to delete the profile.')
            warn pastel.red(e.message)
            exit(1)
          end
        rescue StandardError => e
          spinner&.error(pastel.red('(Unexpected error)'))
          warn pastel.red('An unexpected error occurred while deleting the profile.')
          warn pastel.red(e.message)
          exit(1)
        end
      end
    end
  end
end
