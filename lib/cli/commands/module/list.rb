# frozen_string_literal: true

require 'pastel'

require_relative '../../../services/sys_info/sys_info'
require_relative '../../../services/config_manager/config_manager'

module AlcesJob
  module CLI
    module Commands
      class ModuleList < Dry::CLI::Command
        AlcesJob::CLI.register 'module list', self

        desc 'Lists all available modules on the system'

        option :show_description, type: :boolean, aliases: ['-d'], default: false, desc: 'Displays the description for the package'
        option :show_full_name, type: :boolean, aliases: ['-f'], default: false, desc: 'Shows the modules full name which is used to load it'
        option :hide_categories, type: :boolean, aliases: ['-h'], default: false, desc: 'Hides the category name while displaying modules'
        option :show_config_blocked, type: :boolean, aliases: ['-b'], default: false, desc: 'Shows the packages that are blocked by the config file'

        def call(**options)
          pastel = Pastel.new

          # ------------------------------------------------------------
          # Get packages
          # ------------------------------------------------------------
          package_categories = AlcesJob::Services::SysInfo.load_info[:packages]
          package_blacklist = Services::ConfigManager.new({}).module_blacklist

          if package_categories.empty?
            puts pastel.red.bold("\nNo packages available\n")
            exit(0)
          end

          # ------------------------------------------------------------
          # Display packages
          # ------------------------------------------------------------
          package_categories.each do |category_name, packages|
            puts pastel.green.bold("\n#{category_name}:") unless options[:hide_categories]
            packages.each do |package|
              next if !options[:show_config_blocked] && package_blacklist.include?(package[:full_name])

              output = "#{package[:name]} - v#{package[:version]}"
              output <<= " - #{pastel.red('Blocked by config')}" if package_blacklist.include?(package[:full_name])
              output <<= " - #{package[:full_name]}" if options[:show_full_name]
              output <<= " - #{pastel.red('DEPRECATED')}" if package[:deprecated]
              output <<= pastel.yellow("\n#{package[:description]}") if options[:show_description]
              puts output
            end
          end

          puts
          exit(0)

        # ------------------------------------------------------------
        # Unexpected errors
        # ------------------------------------------------------------
        rescue StandardError => e
          warn pastel.red("\nAn unexpected error occurred while modifying the script:")
          warn pastel.red("#{e.message}\n")
          exit(1)
        end
      end
    end
  end
end
