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

        config = load_config

        @output = []

        if config.empty?
          @config = options
          @module_blacklist = []
          return
        end

        unless options.empty?
          options.each_key do |key|
            key_str = key.to_s
            @output.push(pastel.yellow("You are overwriting the system admin defined #{key_str}")) if config['flags'].key?(key_str) && config['flags'][key_str]['warn']
          end
        end

        config = config['flags'].to_h do |key, value|
          [key.to_sym, value['default']]
        end

        @module_blacklist = config['module_blacklist']

        @config = config.merge(options)
      end

      def self.load_config
        paths = Services::Paths.new

        AlcesJob::Services.deep_merge(
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
      end
    end
  end
end
