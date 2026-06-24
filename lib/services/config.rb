# frozen_string_literal: true

require 'yaml'

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
