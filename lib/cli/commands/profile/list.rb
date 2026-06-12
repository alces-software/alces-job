# frozen_string_literal: true

require 'dry/cli'
require 'yaml'

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
          profile_files = Dir.glob(File.join(Dir.home, @profile_dir, '*.yaml'))

          if profile_files.empty?
            puts 'No profiles found.'
            return
          end

          profile_files.each do |path|
            puts File.basename(path, '.yaml')
          end
        rescue Errno::ENOENT
          puts 'No profile directory exists.'
        end
      end
    end
  end
end
