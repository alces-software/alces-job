# frozen_string_literal: true

require 'dry/cli'

# Import subcommands like this
require_relative '../../services/interactive_wizard'
require_relative '../../services/sysinfo/sysinfo'

module AlcesJob
  module CLI
    module Commands
      class Wizard < Dry::CLI::Command
        AlcesJob::CLI.register 'interactive', self, aliases: ['-i', '--interactive']
        desc 'This runs the interactive wizard'

        def call(*)
          AlcesJob::Services::InteractiveWizard.new.call
        end
      end
    end
  end
end
