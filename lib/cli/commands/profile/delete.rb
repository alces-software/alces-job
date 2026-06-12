# frozen_string_literal: true

require 'dry/cli'
require 'yaml'
require 'pastel'
require 'tty-spinner'
require 'tty-prompt'

module AlcesJob
  module CLI
    module Commands
      class ProfileDelete < Dry::CLI::Command
        AlcesJob::CLI.register 'profile delete', self
        desc 'Deletes a saved profile'

        option :profile, type: :string, desc: 'The name of the profile'

        def initialize
          @profile_dir = YAML.load_file(File.expand_path('../../../../config/config.yaml', __dir__))['user_profile_dir']
        end

        def call(**options)
          pastel = Pastel.new
          prompt = TTY::Prompt.new

          unless options[:profile].nil?
            puts pastel.red("\nNo profile name was provided\n")
            exit(1)
          end

          profile_name = options[:profile].strip
          profile_path = File.join(Dir.home, @profile_dir, "#{profile_name}.yaml")

          unless File.exist?(profile_path)
            puts pastel.red("\nThe profile you're trying to delete doesn't exist\n")
            exit(1)
          end

          exit(0) if prompt.yes?("\nAre you sure you want to delete your #{profile_name} profile?", default: false)

          spinner = TTY::Spinner.new(
            "\n[:spinner] deleting profile ...",
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          spinner.auto_spin

          begin
            File.unlink(profile_path)
            spinner.success('(deleted)')

            puts pastel.green("\nSuccessfully deleted the profile\n")
            exit(0)
          rescue StandardError => e
            spinner.error('(failed)')
            puts pastel.red("\nFailed to delete the profile: #{e.message}\n")
            exit(1)
          end
        end
      end
    end
  end
end
