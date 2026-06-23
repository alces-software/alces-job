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

        def call(profile_name:)
          pastel = Pastel.new
          prompt = TTY::Prompt.new

          unless profile_name.to_s.strip.empty?
            puts pastel.red("\nNo profile name was provided\n")
            exit(1)
          end

          profile_name = profile.strip
          profile_path = Services::Paths.new.user_profile_path(profile_name)

          begin
            unless File.exist?(profile_path)
              puts pastel.red("\nThe profile doesn't exist\n")
              exit(1)
            end
          rescue StandardError => e
            puts pastel.red("\nAn error occurred while checking if the profile exits:\n#{e.message}\n")
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

            puts pastel.green("\nSuccessfully deleted the profile\n")
            exit(0)
          rescue StandardError => e
            spinner.error(pastel.red('(delete error)'))
            puts pastel.red("\nFailed to delete the profile:\n#{e.message}\n")
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
