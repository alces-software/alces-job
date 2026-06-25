# frozen_string_literal: true

require 'dry/cli'
require 'dry/cli/completion'
require 'tty-prompt'

require_relative '../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class CompletionBash < Dry::CLI::Command
        AlcesJob::CLI.register 'completion', self
        desc 'Installs tab completion for Alces-Job'

        START_MARKER = '# >>> alces-job completion >>>'
        END_MARKER = '# <<< alces-job completion <<<'

        def call(**)
          return unless TTY::Prompt.new.yes?('Do you want to install tab completion for Alces-Job?', default: false)

          case install
          when :already_installed
            puts 'Tab completion is already installed'
          when :installed
            puts 'Tab completion has now been installed'
          end
        end

        private

        def install
          paths = Services::Paths.new

          return :already_installed if Dir.exist?(paths.user_bash_completion_path)

          Dir.mkdir(paths.user_bash_completion_dir)

          File.write(paths.user_bash_completion_path, Dry::CLI::Completion::Generator.new(MyRegistry).call(shell: 'bash'))

          bashrc_path = paths.user_bashrc_path
          bashrc_content = File.read(bashrc_path)
          bashrc_content << <<~BASH
            # Load user-specific bash completions
            if [ -d ~/.bash_completion.d ]; then
                for file in ~/.bash_completion.d/*; do
                    [ -f "$file" ] && . "$file"
                done
            fi
          BASH
          File.write(bashrc_path, bashrc_content)

          :installed
        end
      end
    end
  end
end
