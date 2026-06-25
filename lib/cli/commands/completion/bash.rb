# frozen_string_literal: true

require 'dry/cli'
require 'dry/cli/completion'

module AlcesJob
  module CLI
    module Commands
      class CompletionBash < Dry::CLI::Command
        AlcesJob::CLI.register 'completion bash', self
        desc 'Prints Bash tab completion script for alces-job'

        def call(**)
          script = Dry::CLI::Completion::Generator
                  .new(AlcesJob::CLI)
                  .call(shell: 'bash')
                puts script
        end
      end
    end
  end
end

