# frozen_string_literal: true

require 'dry/cli'
require 'yaml'
require 'pastel'

module AlcesJob
  module CLI
    module Commands
      class ProfileShow < Dry::CLI::Command
        AlcesJob::CLI.register 'profile show', self
        desc 'Shows the contents of a saved profile'

        option :profile, type: :string, desc: 'The name of the profile to display'

        def initialize
          @profile_dir = YAML.load_file(File.expand_path('../../../../config/config.yaml', __dir__))['user_profile_dir']
        end

        def call(**options)
          pastel = Pastel.new

          if options[:profile].nil?
            puts pastel.red("\nNo profile name supplied\n")
            exit(1)
          end

          profile_path = File.join(Dir.home, @profile_dir, "#{options[:profile]}.yaml")

          unless File.exist?(profile_path)
            puts pastel.red("\nProfile #{options[:profile]} not found\n")
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
