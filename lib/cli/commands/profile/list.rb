# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class ProfileList < Dry::CLI::Command
        AlcesJob::CLI.register 'profile list', self

        desc 'List all saved user profiles.'

        def call(*)
          pastel = Pastel.new

          # ------------------------------------------------------------
          # Find saved profiles
          # ------------------------------------------------------------
          begin
            profile_files = Dir.glob(Services::Paths.new.user_profile_path('*'))
          rescue Errno::EACCES
            warn pastel.red("\nYou do not have permission to view saved profiles.\n")
            exit(1)
          rescue Errno::ENOENT, Errno::ENOTDIR
            warn pastel.red("\nThe profiles directory could not be found or is invalid.\n")
            exit(1)
          rescue StandardError => e
            warn pastel.red("\nFailed to retrieve the list of saved profiles.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Display profiles
          # ------------------------------------------------------------
          if profile_files.empty?
            warn pastel.yellow("\nNo saved profiles were found.\n")
            exit(0)
          end

          puts pastel.green("\nAvailable profiles:")

          profile_files.sort.each do |path|
            puts "#{File.basename(path, '.yaml')} ~ #{path}"
          end

          puts

          exit(0)

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          warn pastel.red("\nAn unexpected error occurred while listing profiles.\n")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
