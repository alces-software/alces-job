# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../services/interactive2'

module AlcesJob
  module CLI
    module Commands
      class New < Dry::CLI::Command
        AlcesJob::CLI.register 'new', self
        desc 'This runs the interactive script builder'

        def call(*)
          pastel = Pastel.new
          AlcesJob::Services::Interactive2.new.call

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
