# frozen_string_literal: true

require 'pastel'

require_relative '../../../services/sys_info/sys_info'

module AlcesJob
  module CLI
    module Commands
      class ModuleSearch < Dry::CLI::Command
        AlcesJob::CLI.register 'module search', self

        desc "Search through packages that are on you're system"

        option :module_name, type: :string, aliases: ['-n'], desc: 'Filters by the name provided'
        option :version, type: :string, aliases: ['-v'], desc: 'Filters by the version'
        option :category, type: :string, aliases: ['-c'], desc: 'Filters by the category'
        option :show_description, type: :boolean, aliases: ['-d'], default: false, desc: 'Displays the description for the package'
        option :show_full_name, type: :boolean, aliases: ['-f'], default: false, desc: 'Shows the modules full name which is used to load it'
        option :hide_categories, type: :boolean, aliases: ['-k'], default: false, desc: 'Hides the category name while displaying modules'
        option :show_config_blocked, type: :boolean, aliases: ['-b'], default: false, desc: 'Shows the packages that are blocked by the config file'

        def call(**options)
          pastel = Pastel.new

          # ------------------------------------------------------------
          # Check options
          # ------------------------------------------------------------
          if options.length == 1
            puts pastel.red.bold("\nNo filter options were provided. Use --help to see available flags.\n")
            exit(1)
          end

          # ------------------------------------------------------------
          # Get packages
          # ------------------------------------------------------------
          packages = AlcesJob::Services::SysInfo.load_info[:packages]
          package_blacklist = Services::ConfigManager.new({}).module_blacklist

          if packages.empty?
            puts pastel.red.bold("\nNo packages available to search through\n")
            exit(0)
          end

          # ------------------------------------------------------------
          # Filter name
          # ------------------------------------------------------------
          packages = filter_name(options, packages) unless options[:module_name].nil?

          if packages.empty?
            puts pastel.red.bold("\nNo modules found\n")
            exit(0)
          end

          # ------------------------------------------------------------
          # Filter version
          # ------------------------------------------------------------
          packages = filter_version(options, packages) unless options[:version].nil?

          if packages.empty?
            puts pastel.red.bold("\nNo modules found\n")
            exit(0)
          end

          # ------------------------------------------------------------
          # Filter category
          # ------------------------------------------------------------
          packages = filter_category(options, packages) unless options[:category].nil?

          if packages.empty?
            puts pastel.red.bold("\nNo modules found\n")
            exit(0)
          end

          # ------------------------------------------------------------
          # Display packages
          # ------------------------------------------------------------
          packages.each do |category_name, packages|
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

        private

        # Filters the modules by name
        # @param [Hash] options
        # @param [Hash] packages
        # @return [Hash]
        def filter_name(options, packages)
          filtered_packages = {}
          packages.each do |category_name, packages|
            packages.each do |package|
              if package[:version].to_s.downcase.include?(options[:version].to_s.downcase)
                filtered_packages[category_name] ||= []
                filtered_packages[category_name] << package
              end
            end
          end
          filtered_packages
        end

        # Filters the modules by version
        # @param [Hash] options
        # @param [Hash] packages
        # @return [Hash]
        def filter_version(options, packages)
          filtered_packages = {}
          packages.each do |category_name, packages|
            packages.each do |package|
              if package[:version].to_s.downcase.include?(options[:version].to_s.downcase)
                filtered_packages[category_name] ||= []
                filtered_packages[category_name] << package
              end
            end
          end
          filtered_packages
        end

        # Filters the modules by category
        # @param [Hash] options
        # @param [Hash] packages
        # @return [Hash]
        def filter_category(options, packages)
          filtered_packages = {}
          packages.each do |category_name, packages|
            next unless category_name.to_s.downcase.include?(options[:category].to_s.downcase)

            packages.each do |package|
              filtered_packages[category_name] ||= []
              filtered_packages[category_name] << package
            end
          end
          filtered_packages
        end
      end
    end
  end
end
