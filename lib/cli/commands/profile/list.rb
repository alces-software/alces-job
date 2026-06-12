# frozen_string_literal: true

require 'dry/cli'
require 'yaml'
require 'pastel'

module AlcesJob
  module CLI
    module Commands
      class ProfileList < Dry::CLI::Command
        AlcesJob::CLI.register 'profile list', self
        desc 'Lists saved user profiles'

        def initialize
          @profile_dir = YAML.load_file(File.expand_path('../../../../config/config.yaml', __dir__))['user_profile_dir']
        end

        def call(*)
          Pastel.new

          profile_files = Dir.glob(File.join(Dir.home, @profile_dir, '*.yaml'))

          if profile_files.empty?
            puts "\nNo profiles found\n"
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
