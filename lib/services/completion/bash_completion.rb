# frozen_string_literal: true

require 'fileutils'

module AlcesJob
  module Services
    class BashCompletionInstaller
      START_MARKER = '# >>> alces-job completion >>>'
      END_MARKER = '# <<< alces-job completion <<<'

      def initialize(home_dir: ENV.fetch('HOME', Dir.home))
        @bashrc_path = File.join(home_dir, '.bashrc')
      end

      def install
        existing_contents = File.exist?(@bashrc_path) ? File.read(@bashrc_path) : ''

        return :already_installed if existing_contents.include?(START_MARKER)

        completion_block = <<~BASH

          #{START_MARKER}
          if command -v alces-job >/dev/null 2>&1; then
            source <(alces-job completion bash)
          fi
          #{END_MARKER}
        BASH

        FileUtils.mkdir_p(File.dirname(@bashrc_path))
        File.write(@bashrc_path, existing_contents + completion_block)

        :installed
      end
    end
  end
end