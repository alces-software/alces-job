# frozen_string_literal: true

require 'tempfile'
require 'shellwords'
require 'English'

module AlcesJob
  module Services
    module Editor
      module_function

      def edit_script_in_editor(content)
        editor = ENV['VISUAL'] || ENV['EDITOR'] || 'vi'

        Tempfile.create(['alces-job-', '.slurm']) do |file|
          file.write(content)
          file.flush

          editor_command = Shellwords.split(editor)
          editor_ok = system(*editor_command, file.path)

          warn "Editor exited with status #{$CHILD_STATUS&.exitstatus}; continuing with current file contents." unless editor_ok

          File.read(file.path)
        end
      end

      def edited_job_name(script)
        script.each_line do |line|
          match = line.match(/\A#SBATCH\s+(?:--job-name(?:=|\s+)|-J\s*)(?<job_name>[^\s#]+)/)
          return match[:job_name] if match
        end

        nil
      end
    end
  end
end
