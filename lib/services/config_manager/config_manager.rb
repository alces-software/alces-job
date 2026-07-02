# frozen_string_literal: true

require 'yaml'
require 'pastel'

require_relative '../paths/paths'
require_relative '../deep_merge/deep_merge'

module AlcesJob
  module Services
    class ConfigManager
      attr_reader :config, :output, :module_blacklist

      # Applies the user and admin configs when they are available
      # @param [Hash] options
      # @return [Hash]
      def initialize(options)
        pastel = Pastel.new
        paths = Services::Paths.new

        config = AlcesJob::Services.deep_merge(
          begin
            YAML.load_file(paths.user_config_path) || {}
          rescue Errno::ENOENT
            {}
          end,
          begin
            YAML.load_file(paths.admin_config_path) || {}
          rescue Errno::ENOENT
            {}
          end
        )

        @output = []

        if config.empty?
          @config = options
          @module_blacklist = []
          return
        end

        @module_blacklist = config['module_blacklist']

        unless options.empty?
          options.each_key do |key|
            key_str = key.to_s
            @output.push(pastel.yellow("You are overwriting the system admin defined #{key_str}")) if config['flags'].key?(key_str) && config['flags'][key_str]['warn']
          end
        end

        config = config['flags'].to_h do |key, value|
          [key.to_sym, value['default']]
        end

        config = config.merge(options)

        filtered_modules = []
        config[:modules].each do |package|
          if module_blacklist.include?(package)
            @output.push(pastel.red("#{package} has been removed because it's blocked by the config"))
          else
            filtered_modules << package
          end
        end
        config['modules'] = filtered_modules

        @config = config
      end
    end
  end
end
