# frozen_string_literal: true

require 'yaml'
require 'pastel'

require_relative '../paths/paths'
require_relative '../deep_merge/deep_merge'

module AlcesJob
  module Services
    class ConfigManager
      attr_reader :config, :output

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

        config_keys = config['values'].keys

        @output = []

        unless options.empty?
          options.each_key do |key|
            key_str = key.to_s
            @output.push(pastel.yellow("You are overwriting the system admin defined #{key_str}")) if config_keys.include?(key_str) && config['values'][key_str]['warn']
          end
        end

        @config = config.merge(options)
      end
    end
  end
end
