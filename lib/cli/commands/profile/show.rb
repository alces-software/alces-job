# frozen_string_literal: true

require 'dry/cli'
require 'yaml'

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
          return puts 'No profile name supplied.' if options[:profile].nil?

          profile_path = File.join(@profile_dir, "#{options[:profile]}.yaml")

          unless File.exist?(profile_path)
            puts "Profile #{options[:profile]} not found."
            return
          end

          puts File.read(profile_path)
        rescue Errno::ENOENT
          puts 'No profile directory exists.'
        end
      end
    end
  end
end
