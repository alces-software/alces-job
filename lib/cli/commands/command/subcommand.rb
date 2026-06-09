# frozen_string_literal: true

require 'dry/cli'

module AlcesJob
  module CLI
    module Commands
      class Subcommand < Dry::CLI::Command
        AlcesJob::CLI.register 'command subcommand', self
        desc 'This is a subcommand example'

        def call(*)
          puts 'This is a subcommand example'
        end
      end
    end
  end
end
