# frozen_string_literal: true

require 'yaml'

require_relative 'paths/paths'

module AlcesJob
  module Services
    class ConfigManager
      def load_config
        paths = Services::Paths.new
        admin_path = paths.admin_config_path

        if File.exist?(admin_path)
          YAML.load_file(admin_path)
        else
          {}
        end
      end
    end
  end
end
