# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'yaml'
require 'fileutils'

require_relative '../../../services/sys_info/sys_info'
require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class SysInfoInit < Dry::CLI::Command
        AlcesJob::CLI.register 'sysinfo init', self

        desc 'Generates and saves the initial system information'

        def call(*)
          pastel = Pastel.new
          path = Services::Paths.new

          system_info_file_path =
            if Process.uid.zero?
              path.admin_system_info_path
            else
              path.user_system_info_path
            end

          puts

          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          # ------------------------------------------------------------
          # Check system info file
          # ------------------------------------------------------------
          spinner.update(title: 'checking system information')
          spinner.auto_spin

          begin
            if File.exist?(system_info_file_path)
              data = YAML.load_file(system_info_file_path)

              if data
                spinner.error(pastel.red('(Already exists)'))

                warn pastel.red("\nSystem information already exists.")
                warn pastel.yellow('Run alces-job sysinfo update to update the existing file.')

                exit(1)
              end

              spinner.success(pastel.green('(Empty file)'))
            else
              spinner.success(pastel.green('(Not found)'))
            end
          rescue StandardError => e
            spinner.error(pastel.red('(Failed to check)'))
            warn pastel.red("\nFailed to check system information.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Collect system information
          # ------------------------------------------------------------
          spinner.update(title: 'collecting system information')
          spinner.auto_spin

          begin
            system_data = Services::SysInfo.all_info
            spinner.success(pastel.green('(Collected)'))
          rescue StandardError => e
            spinner.error(pastel.red('(Failed)'))
            warn pastel.red("\nFailed to collect system information.")
            warn pastel.yellow("System tools may not be available or accessible.\n")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Write system information file
          # ------------------------------------------------------------
          spinner.update(title: 'saving system information')
          spinner.auto_spin

          begin
            FileUtils.mkdir_p(File.dirname(system_info_file_path))
            File.write(system_info_file_path, system_data.to_yaml)

            spinner.success(pastel.green('(Saved)'))
            puts pastel.green("\nSystem information created successfully.")
            puts pastel.green("Written to: #{system_info_file_path}\n")
            exit(0)
          rescue Errno::ENOSPC
            spinner.error(pastel.red('(Disk full)'))
            warn pastel.red("\nNot enough disk space to save system information.\n")
            exit(1)
          rescue Errno::EACCES, Errno::EROFS
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red("\nYou do not have permission to save system information here.\n")
            exit(1)
          rescue StandardError => e
            spinner.error(pastel.red('(Write failed)'))
            warn pastel.red("\nFailed to save system information.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          spinner&.error(pastel.red('(Unexpected error)'))
          warn pastel.red("\nAn unexpected error occurred while running the command.")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
