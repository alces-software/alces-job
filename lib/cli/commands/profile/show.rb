# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class ProfileShow < Dry::CLI::Command
        AlcesJob::CLI.register 'profile show', self
        desc 'Shows the contents of a saved profile'

        argument :profile_name, require: true, type: :string, desc: 'The name of the profile to display'

        def call(profile_name:, **)
          pastel = Pastel.new

          if profile_name.to_s.strip.empty?
            warn pastel.red("\nNo profile name was provided.\n")
            exit(1)
          end

          profile_path = Services::Paths.new.user_profile_path(profile_name.strip)

          begin
            unless File.exist?(profile_path)
              warn pastel.red("\nThe profile doesn't exist.\n")
              exit(1)
            end
          rescue StandardError => e
            warn pastel.red("\nAn error occurred while checking if the profile exits:\n#{e.message}\n")
            exit(1)
          end

          begin
            puts
            puts "# Profile: #{profile_name}"
            puts "# Path: #{profile_path}"
            puts File.read(profile_path)
            puts
            exit(0)
          rescue Errno::ENOENT
            warn pastel.red("\nThe profile could not be found.\n")
            exit(1)
          rescue Errno::EACCES
            warn pastel.red("\nYou do not have permission to read this profile\n")
            exit(1)
          rescue Errno::EISDIR
            warn pastel.red("\nThe profile path points to a directory, not a profile file. \n")
            exit(1)
          rescue StandardError => e
            warn pastel.red("\nFailed to read the profile:\n#{e.message}\n")
            exit(1)
          end
        rescue StandardError => e
          warn pastel.red("\nAn error occurred while running the command:\n#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
