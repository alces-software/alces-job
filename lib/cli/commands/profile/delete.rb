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
          config = YAML.load_file(File.expand_path('../../../../config.yaml', __dir__))
          @profile_dir = config['user_profile_dir']
        end

        def call(**options)
          pastel = Pastel.new
          prompt = TTY::Prompt.new

          return puts pastel.red("\nNo profile name was provided\n") if options[:profile].nil?

          profile_name = options[:profile].strip
          profile_path = "#{@profile_dir}/#{profile_name}.yaml"

          return puts pastel.red("\nThe profile you're trying to delete doesn't exist\n") unless File.exist?(profile_path)

          return if prompt.yes?("\nAre you sure you want to delete your #{profile_name} profile?", default: false)

          spinner = TTY::Spinner.new(
            "\n[:spinner] deleting profile ...",
            success_mark: pastel.green('✔'),
            error_mark: pastel.red('✖')
          )

          spinner.auto_spin

          if File.unlink(profile_path) == 1
            spinner.success('(deleted)')
            puts pastel.green("\nSuccessfully deleted the profile\n")
          else
            spinner.error('(failed)')
            puts pastel.red("\nFailed to delete the profile\n")
          end
        end
      end
    end
  end
end
