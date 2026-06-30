# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class ProfileShow < Dry::CLI::Command
        AlcesJob::CLI.register 'profile show', self

        desc 'Display the contents of a saved profile.'

        argument :profile_name, required: true, type: :string,
                                desc: 'The name of the profile to display'

        def call(profile_name:, **)
          pastel = Pastel.new

          # ------------------------------------------------------------
          # Validate input
          # ------------------------------------------------------------
          if profile_name.to_s.strip.empty?
            warn pastel.red("\nNo profile name was provided.")
            warn pastel.yellow("Please specify the name of the profile to display.\n")
            exit(1)
          end

          profile_name = profile_name.strip
          profile_path = Services::Paths.new.user_profile_path(profile_name)

          # ------------------------------------------------------------
          # Check profile exists
          # ------------------------------------------------------------
          begin
            unless File.exist?(profile_path)
              warn pastel.red("\nProfile not found: #{profile_name}")
              warn pastel.yellow("Check the profile name and try again.\n")
              exit(1)
            end
          rescue StandardError => e
            warn pastel.red("\nFailed to check whether the profile exists.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Read profile
          # ------------------------------------------------------------
          begin
            puts
            puts "# Profile: #{profile_name}"
            puts "# Path: #{profile_path}"
            puts File.read(profile_path)
            puts

            exit(0)
          rescue Errno::ENOENT
            warn pastel.red("\nThe profile could not be found.")
            warn pastel.yellow("It may have been moved or deleted.\n")
            exit(1)
          rescue Errno::EACCES
            warn pastel.red("\nYou do not have permission to read this profile.\n")
            exit(1)
          rescue Errno::EISDIR
            warn pastel.red("\nThe profile path refers to a directory instead of a file.\n")
            exit(1)
          rescue StandardError => e
            warn pastel.red("\nFailed to read the profile.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          warn pastel.red("\nAn unexpected error occurred while running the command.")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
