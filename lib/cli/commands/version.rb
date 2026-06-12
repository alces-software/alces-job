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
          art = <<~ART

             'o`
            'ooo`
            `oooo`
             `oooo`         'o` #{pastel.white("v#{AlcesJob::VERSION}")}
               `ooooo`  `ooooo
                  `oooo:oooo`
                     `v  -[ #{pastel.white('Alces Software')} ]-

            #{AlcesJob::GITHUB_URL}
          ART

          puts pastel.decorate(art, :bright_blue, :bold)
          exit(0)
        end
      end
    end
  end
end
