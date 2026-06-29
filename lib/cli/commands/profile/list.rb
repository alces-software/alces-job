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
            warn pastel.red('You do not have permission to view saved profiles.')
            exit(1)
          rescue Errno::ENOENT, Errno::ENOTDIR
            warn pastel.red('The profiles directory could not be found or is invalid.')
            exit(1)
          rescue StandardError => e
            warn pastel.red('Failed to retrieve the list of saved profiles.')
            warn pastel.red(e.message)
            exit(1)
          end

          # ------------------------------------------------------------
          # Display profiles
          # ------------------------------------------------------------
          if profile_files.empty?
            warn pastel.yellow('No saved profiles were found.')
            exit(0)
          end

          puts pastel.green("\nAvailable profiles:")

          profile_files.sort.each do |path|
            puts "#{File.basename(path, '.yaml')} ~ #{path}"
          end

          puts

          exit(0)
        rescue StandardError => e
          warn pastel.red('An unexpected error occurred while listing profiles.')
          warn pastel.red(e.message)
          exit(1)
        end
      end
    end
  end
end
