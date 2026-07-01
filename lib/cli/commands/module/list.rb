# frozen_string_literal: true

require 'pastel'

require_relative '../../../services/sys_info/sys_info'

module AlcesJob
  module CLI
    module Commands
      class ModuleList < Dry::CLI::Command
        AlcesJob::CLI.register 'module list', self

        desc 'Lists all available modules on the system'

        option :show_description, type: :boolean, aliases: ['-d'], default: false, desc: 'Displays the description for the package'

        def call(*)
          pastel = Pastel.new
          package_categories = AlcesJob::Services::SysInfo.load_info[:packages]

          if package_categories.empty?
            puts pastel.red.bold("\nNo packages available\n")
            exit(0)
          end

          package_categories.each do |category_name, packages|
            puts pastel.green.bold("\n#{category_name}:")
            packages.each do |package|
              output = "#{package[:name]} - v#{package[:version]}"
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
