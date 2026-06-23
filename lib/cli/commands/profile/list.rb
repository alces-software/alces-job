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

          profile_files = Dir.glob(Services::Paths.new.user_profile_path('*'))

          if profile_files.empty?
            puts pastel.red("\nNo profiles found\n")
            exit(0)
          end

          profile_files.each do |path|
            puts File.basename(path, '.yaml')
          end
          exit(0)
        rescue Errno::ENOENT
          puts pastel.red("\nNo profile directory exists\n")
          exit(1)
        end
      end
    end
  end
end
