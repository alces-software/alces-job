# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

module AlcesJob
  module CLI
    module Commands
      class Version < Dry::CLI::Command
        AlcesJob::CLI.register 'version', self, aliases: ['-v', '--version']
        desc 'Print version'

        def call(*)
          pastel = Pastel.new
          puts pastel.bright_blue.bold("
  'o`
 'ooo`
 `oooo`
  `oooo`         'o` #{pastel.white("v#{AlcesJob::VERSION}")}
    `ooooo`  `ooooo
       `oooo:oooo`
          `v  -[ #{pastel.white('alces software')} ]-
                        ")
        end
      end
    end
  end
end
