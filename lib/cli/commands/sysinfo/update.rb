# frozen_string_literal: true

require 'dry/cli'
require 'pastel'
require 'tty-spinner'
require 'yaml'

require_relative '../../../services/sys_info/sys_info'
require_relative '../../../services/paths/paths'

module AlcesJob
  module CLI
    module Commands
      class SysInfoUpdate < Dry::CLI::Command
        AlcesJob::CLI.register 'sysinfo update', self

        desc 'Updates the system information file'

        option :partition, type: :boolean, aliases: ['-p'], default: false, desc: 'Update partition information'
        option :package, type: :boolean, aliases: ['-k'], default: false, desc: 'Update package information'
        option :all, type: :boolean, aliases: ['-a'], default: false, desc: 'Update all system information'

        def call(**options)
          pastel = Pastel.new

          system_info_file_path =
            if Process.uid.zero?
              Services::Paths.new.admin_system_info_path
            else
              Services::Paths.new.user_system_info_path
            end

          # ------------------------------------------------------------
          # Validate input
          # ------------------------------------------------------------
          filtered_options = options.select { |_key, value| value }

          puts

          spinner = TTY::Spinner.new(
            '[:spinner] :title ...',
            success_mark: pastel.green('✓'),
            error_mark: pastel.red('✗')
          )

          # ------------------------------------------------------------
          # Check system info file exists
          # ------------------------------------------------------------
          spinner.update(title: 'loading system information')
          spinner.auto_spin

          begin
            unless File.exist?(system_info_file_path)
              spinner.error(pastel.red('(Not found)'))
              warn pastel.red("\nSystem information file not found.")
              warn pastel.yellow("Run 'sysinfo init' to create one first.\n")
              exit(1)
            end
          rescue StandardError => e
            spinner.error(pastel.red('(Check failed)'))
            warn pastel.red("\nFailed to check system information file.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Load system info file
          # ------------------------------------------------------------
          begin
            system_data = YAML.load_file(system_info_file_path)
          rescue StandardError => e
            spinner.error(pastel.red('(Load failed)'))
            warn pastel.red("\nFailed to load system information file.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          if system_data.nil?
            spinner.error(pastel.red('(Empty file)'))
            warn pastel.red("\nSystem information file is empty or invalid.")
            warn pastel.yellow("Run 'sysinfo init' to generate a new one.\n")
            exit(1)
          end

          spinner.success(pastel.green('(Loaded)'))

          # ------------------------------------------------------------
          # Collect updates
          # ------------------------------------------------------------
          spinner.update(title: 'collecting system information updates')
          spinner.auto_spin

          begin
            if filtered_options[:all] || filtered_options.empty?
              system_data = Services::SysInfo.all_info
            else
              filtered_options.each_key do |key|
                case key
                when :partition
                  system_data[:partitions] = Services::SysInfo.partition_info
                when :package
                  system_data[:packages] = Services::SysInfo.package_info
                end
              end
            end
          rescue StandardError => e
            spinner.error(pastel.red('(Failed)'))
            warn pastel.red("\nFailed to collect system information updates.")
            warn pastel.red("#{e.message}\n")
            exit(1)
          end

          spinner.success(pastel.green('(Collected)'))

          # ------------------------------------------------------------
          # Write system info file
          # ------------------------------------------------------------
          spinner.update(title: 'saving system information')
          spinner.auto_spin

          begin
            File.write(system_info_file_path, system_data.to_yaml)

            spinner.success(pastel.green('(Saved)'))
            puts pastel.green("\nSystem information updated successfully.")
            puts pastel.green("Written to: #{system_info_file_path}\n")
            exit(0)
          rescue Errno::ENOSPC
            spinner.error(pastel.red('(Disk full)'))
            warn pastel.red("\nNot enough disk space to save the system information changes.\n")
            exit(1)
          rescue Errno::EACCES, Errno::EROFS
            spinner.error(pastel.red('(Permission denied)'))
            warn pastel.red("\nYou do not have permission to edit the system information file.\n")
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
