# frozen_string_literal: true

require 'dry/cli'
require 'dry/cli/completion'
require 'tty-prompt'
require 'fileutils'

require_relative '../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class CompletionBash < Dry::CLI::Command
        AlcesJob::CLI.register 'completion', self
        desc 'Installs tab completion for Alces-Job'

        START_MARKER = '# >>> alces-job completion >>>'
        END_MARKER   = '# <<< alces-job completion <<<'

        def call(**)
          puts
          return unless TTY::Prompt.new.yes?(
            'Do you want to install tab completion for Alces-Job?',
            default: false
          )

          install
          puts
          puts 'Tab completion has been installed. Restart your terminal to activate it.'
          puts
        end

        private

        def install
          paths = Services::Paths.new

          if Process.euid.zero?
            install_system(paths)
          else
            install_user(paths)
          end

          :installed
        end

        def install_user(paths)
          FileUtils.mkdir_p(paths.user_bash_completion_dir)

          completion_path = paths.user_bash_completion_path

          File.write(
            completion_path,
            Dry::CLI::Completion::Generator.new(AlcesJob::CLI).call(shell: 'bash')
          )

          install_into_file(paths.user_bashrc_path, paths.user_bash_completion_path)
        end

        def install_system(paths)
          FileUtils.mkdir_p(paths.system_bash_completion_dir)

          completion_path = paths.system_bash_completion_path

          File.write(
            completion_path,
            Dry::CLI::Completion::Generator.new(AlcesJob::CLI).call(shell: 'bash')
          )

          install_into_file('/etc/bashrc', completion_path)
          install_into_file('/etc/bash.bashrc', completion_path)

          install_profile_d(completion_path)
        end

        def install_into_file(file, completion_path)
          return unless File.exist?(file)

          content = File.read(file)
          return if content.include?(START_MARKER)

          content << <<~SH

            #{START_MARKER}
            # Alces-job completion
            if [ -f #{completion_path} ]; then
              . #{completion_path}
            fi
            #{END_MARKER}
          SH

          File.write(file, content)
        end

        def install_profile_d(completion_path)
          path = '/etc/profile.d/alces-job.sh'

          return if File.exist?(path)

          File.write(path, <<~SH)
            # Alces-job completion

            if [ -f #{completion_path} ]; then
              . #{completion_path}
            fi
          SH
        end
      end
    end
  end
end
