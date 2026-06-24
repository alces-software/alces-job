# frozen_string_literal: true

require 'yaml'
require 'pastel'

require_relative 'paths/paths'

module AlcesJob
  module Services
    class ConfigManager
      def load_config
        paths = Services::Paths.new
        admin_path = paths.admin_config_path
        user_path = paths.user_config_path

        admin_config = if File.exist?(admin_path)
                         YAML.load_file(admin_path)
                       else
                         {}
                       end

        user_config = if File.exist?(user_path)
                        YAML.load_file(user_path)
                      else
                        {}
                      end

        deep_merge(admin_config, user_config)
      end

      def apply_options(options)
        pastel = Pastel.new
        config = load_config
        config_keys = config['values'].keys
        puts
        options.each_key do |key|
          key_str = key.to_s
          puts pastel.yellow("You are overwriting the system admin defined #{key_str}") if config_keys.include?(key_str) && config['values'][key_str]['warn']
        end

        config.merge(options)
      end

      private

      def deep_merge(hash1, hash2)
        hash1.merge(hash2) do |_, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          else
            new_val
          end
        end
      end
    end
  end
end
