# frozen_string_literal: true

require 'tempfile'
require 'shellwords'
require 'English'
require 'diffy'
require 'tty-box'

module AlcesJob
  module Services
    module Editor
      module_function

      def highlight_added_lines(old_content, new_content, pastel)
        diff = Diffy::Diff.new(old_content, new_content, context: 0).to_s

        added_lines = diff.lines.filter_map do |line|
          next unless line.start_with?('+') && !line.start_with?('+++')

          line[1..].chomp
        end

        new_content.lines.map do |line|
          clean_line = line.chomp

          if added_lines.include?(clean_line)
            "#{pastel.green(clean_line)}\n"
          else
            line
          end
        end.join
      end

      def removed_lines(old_content, new_content)
        diff = Diffy::Diff.new(old_content, new_content, context: 0).to_s

        diff.lines.filter_map do |line|
          next unless line.start_with?('-') && !line.start_with?('---')

          removed_line = line[1..].chomp
          next if removed_line.strip.empty?

          removed_line
        end
      end

      def show_removed_lines(old_content, new_content, pastel)
        removed = removed_lines(old_content, new_content)

        return if removed.empty?

        puts pastel.bold.red("\nRemoved lines:")
        removed.each do |line|
          puts pastel.red("- #{line}")
        end
      end

      def show_edited_script_preview(old_content, new_content, pastel)
        highlighted_script = highlight_added_lines(old_content, new_content, pastel)
        box_width = new_content.lines.map { |line| line.chomp.length }.max + 4

        puts TTY::Box.frame(
          highlighted_script,
          title: {
            top_center: pastel.bold.green(' Edited Script Preview ')
          },
          padding: 1,
          border: :thick,
          width: box_width
        )

        show_removed_lines(old_content, new_content, pastel)
      end

      def edit_script_with_preview(content, prompt:, pastel:, validator_class:, editor: nil)
        edited_content = edit_script_in_editor(content, editor: editor)
        puts

        show_edited_script_preview(content, edited_content, pastel)
        puts

        return { status: :cancelled, script: content } unless prompt.yes?('Do you want to save these changes?', default: true)

        validation = validate_content(edited_content, validator_class)
        validator = validation[:validator]

        unless validation[:valid]
          puts
          puts pastel.bold.red('INVALID SCRIPT')
          warn pastel.red("\nThe generated SBATCH script is not valid and was not saved.\n")

          validator.errors.each do |error|
            warn "#{pastel.bold.red('ERROR')}: #{pastel.red(error)}"
          end

          validator.warnings.each do |warning|
            warn pastel.yellow("Warning: #{warning}")
          end

          return { status: :invalid, script: content }
        end

        { status: :saved, script: edited_content }
      end

      def edit_script_in_editor(content, editor: nil)
        editor ||= ENV['VISUAL'] || ENV['EDITOR'] || 'vi'

        Tempfile.create(['alces-job-', '.slurm']) do |file|
          file.write(content)
          file.flush

          editor_command = Shellwords.split(editor)
          system(*editor_command, file.path)

          # warn "Editor #{editor.inspect} exited unsuccessfully; continuing with current file contents." unless editor_opened

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

      def validate_content(content, validator_class)
        Tempfile.create(['generated_script', '.slurm']) do |tempfile|
          tempfile.write(content)
          tempfile.flush

          validator = validator_class.new(tempfile.path)
          {
            validator: validator,
            valid: validator.validate?
          }
        end
      end
    end
  end
end
