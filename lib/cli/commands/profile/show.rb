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

        def call(profile_name:)
          pastel = Pastel.new

          if profile_name.to_s.strip.empty?
            puts pastel.red("\nNo profile name was provided\n")
            exit(1)
          end

          profile_path = Dir.glob(Services::Paths.new.user_profile_path(profile_name.strip))

          begin
            unless File.exist?(profile_path)
              puts pastel.red("\nThe profile doesn't exist\n")
              exit(1)
            end
          rescue StandardError => e
            puts pastel.red("\nAn error occurred while checking if the profile exits:\n#{e.message}\n")
            exit(1)
          end

          puts File.read(profile_path)
          exit(0)
        rescue Errno::ENOENT
          puts pastel.red("\nNo profile directory exists\n")
          exit(1)
        end
      end
    end
  end
end
