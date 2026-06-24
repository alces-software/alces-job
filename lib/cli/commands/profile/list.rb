# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class ProfileList < Dry::CLI::Command
        AlcesJob::CLI.register 'profile list', self
        desc 'Lists saved user profiles'

        def call(*)
          pastel = Pastel.new

          begin
            profile_files = Dir.glob(Services::Paths.new.user_profile_path('*'))
          rescue StandardError => e
            puts pastel.red("\nAn error occurred while getting all the profiles names:\n#{e.message}\n")
            exit(1)
          end

          if profile_files.empty?
            puts pastel.red("\nNo profiles found.\n")
            exit(0)
          end

          puts pastel.green("\nAvailable profiles:")
          profile_files.each do |path|
            puts "#{File.basename(path, '.yaml')} ~ #{path}"
          end
          puts

          exit(0)
        rescue StandardError => e
          puts pastel.red("\nAn error occurred while running the command:\n#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
