# frozen_string_literal: true

require 'dry/cli'
require 'pastel'

require_relative '../../../services/completion/bash_completion_installer'

module AlcesJob
  module CLI
    module Commands
      class CompletionInstall < Dry::CLI::Command
        AlcesJob::CLI.register 'completion install', self
        desc 'Installs Bash tab completion for alces-job'

        def call(**)
          pastel = Pastel.new
          installer = Services::BashCompletionInstaller.new

          case installer.install
          when :installed
            puts pastel.green("\nBash tab completion installed successfully.")
            puts 'Run: source ~/.bashrc'
          when :already_installed
            puts pastel.yellow("\nBash tab completion is already installed.")
            puts 'Run: source ~/.bashrc'
          end
        rescue StandardError => e
          puts pastel.red("\nFailed to install Bash tab completion: #{e.message}")
          exit(1)
        end
      end
    end
  end
end
