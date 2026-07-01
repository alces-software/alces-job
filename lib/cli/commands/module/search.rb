# frozen_string_literal: true

require 'pastel'

require_relative '../../../services/sys_info/sys_info'

module AlcesJob
  module CLI
    module Commands
      class ModuleList < Dry::CLI::Command
        AlcesJob::CLI.register 'module search', self

        desc "Search through packages that are on you're system"

        option :module_name, type: :string, aliases: ['-n'], desc: 'Filters by the name provided'
        option :version, type: :string, aliases: ['-v'], desc: 'Filters by the version'
        option :category, type: :string, aliases: ['-c'], desc: 'Filters by the category'
        option :show_description, type: :boolean, aliases: ['-d'], default: false, desc: 'Displays the description for the package'

        def call(**options)
          pastel = Pastel.new

          if options.length == 1
            puts pastel.red.bold("\nNo filter options were provided. Use --help to see available flags.\n")
            exit(1)
          end

          packages = AlcesJob::Services::SysInfo.package_info

          if packages.empty?
            puts pastel.red.bold("\nNo packages available to search through\n")
            exit(0)
          end

          # ------------------------------------------------------------
          # Filter name
          # ------------------------------------------------------------
          unless options[:module_name].nil?
            filtered_packages = {}
            packages.each do |category_name, packages|
              packages.each do |package|
                if package[:name].to_s.downcase.include?(options[:module_name].to_s.downcase)
                  filtered_packages[category_name] ||= []
                  filtered_packages[category_name] << package
                end
              end
            end
            packages = filtered_packages
          end

          # ------------------------------------------------------------
          # Filter version
          # ------------------------------------------------------------
          unless options[:version].nil?
            filtered_packages = {}
            packages.each do |category_name, packages|
              packages.each do |package|
                if package[:version].to_s.downcase.include?(options[:version].to_s.downcase)
                  filtered_packages[category_name] ||= []
                  filtered_packages[category_name] << package
                end
              end
            end
            packages = filtered_packages
          end

          # ------------------------------------------------------------
          # Filter category
          # ------------------------------------------------------------
          unless options[:category].nil?
            filtered_packages = {}
            packages.each do |category_name, packages|
              next unless category_name.to_s.downcase.include?(options[:category].to_s.downcase)

              packages.each do |package|
                filtered_packages[category_name] ||= []
                filtered_packages[category_name] << package
              end
            end
            packages = filtered_packages
          end

          # ------------------------------------------------------------
          # Display packages
          # ------------------------------------------------------------
          packages.each do |category_name, packages|
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
