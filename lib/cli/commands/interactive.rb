# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

# Import subcommands like this
require_relative '../../services/interactive_wizard'

module AlcesJob
  module CLI
    module Commands
      class Wizard < Dry::CLI::Command
        AlcesJob::CLI.register 'interactive', self, aliases: ['-i', '--interactive']
        desc 'This runs the interactive wizard'

        def call(*)
          pastel = Pastel.new
          AlcesJob::Services::InteractiveWizard.new.call

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          warn pastel.red("\nAn unexpected error occurred while running the command.")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
