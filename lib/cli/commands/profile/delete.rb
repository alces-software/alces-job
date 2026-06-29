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
        desc 'Deletes a saved profile'

        argument :profile_name, require: true, type: :string, desc: 'The name of the profile'

        def call(profile_name:, **)
          pastel = Pastel.new
          prompt = TTY::Prompt.new

          unless profile_name.to_s.strip.empty?
            warn pastel.red("\nNo profile name was provided.\n")
            exit(1)
          end

          profile_name = profile.strip
          profile_path = Services::Paths.new.user_profile_path(profile_name)

          begin
            unless File.exist?(profile_path)
              warn pastel.red("\nThe profile doesn't exist.\n")
              exit(1)
            end
          rescue StandardError => e
            warn pastel.red("\nAn error occurred while checking if the profile exits:\n#{e.message}\n")
            exit(1)
          end

          exit(0) if prompt.yes?("\nAre you sure you want to delete your #{profile_name} profile?", default: false)

          spinner = TTY::Spinner.new(
            "\n[:spinner] deleting profile ...",
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )
          spinner.auto_spin

          begin
            File.unlink(profile_path)
            spinner.success(pastel.green('(deleted)'))
            puts pastel.green("\nSuccessfully deleted the profile.\n")
            exit(0)
          rescue Errno::ENOENT
            spinner.error(pastel.red("\nProfile missing\n"))
            warn pastel.red("\nThe profile could not be found when deletion was attempted.\n")
            exit(1)
          rescue Errno::EACCES, Errno::EROFS
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red("\nUnable to delete the profile due to permissions or a read-only filesystem. \n")
            exit(1)
          rescue Errno::EISDIR
            spinner.error(pastel.red('(Invalid profile path)'))
            warn pastel.red("\nUnable to delete the profile because the path points to a directory. \n")
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(delete error)'))
            warn pastel.red("\nFailed to delete the profile:\n#{e.message}\n")
            exit(1)
          end
        rescue StandardError => e
          spinner&.error(pastel.red('(command error)'))
          warn pastel.red("\nAn error occurred while running the command:\n#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
