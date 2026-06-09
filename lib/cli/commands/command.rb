# frozen_string_literal: true

require 'dry/cli'

# Import subcommands like this
require_relative 'command/subcommand'

module AlcesJob
  module CLI
    module Commands
      class Command < Dry::CLI::Command
        AlcesJob::CLI.register 'command', self
        desc 'This is a command example'

        def call(*)
          puts 'This is the main command example'
        end
      end
    end
  end
end
