# frozen_string_literal: true

require 'xdg'

module AlcesJob
  class Paths
    def initialize
      @xdg = XDG.new
      @system_root = '/etc/alces-job'
      @system_info_file_name = 'system-info'
      @admin_config_file_name = 'admin-config'
    end

    # Get's the path to the users templates dir
    # @return [String]
    def user_template_dir
      @xdg.config_home.join('alces-job', 'templates')
    end

    # Get's the path to the user template specified
    # @param [String] template_name
    # @return [string]
    def user_template_path(template_name)
      File.join(user_template_dir, "#{template_name}.erb")
    end

    # Get's the path to the users profile dir
    # @return [String]
    def user_profile_dir
      @xdg.config_home.join('alces-job', 'profiles')
    end

    # Get's the path to a user specific profile
    # @param [String] profile_name
    # @return [String]
    def user_profile_path(profile_name)
      File.join(user_profile_dir, "#{profile_name}.yaml")
    end

    # Get's the path to the admin template dir
    # @return [String]
    def admin_template_dir
      File.join(@system_root, 'templates')
    end

    # Get's the path to the admin template specified
    # @param [String] template_name
    # @return [String]
    def admin_template_path(template_name)
      File.join(admin_template_dir, "#{template_name}.erb")
    end

    # Get's the path to the admin config file
    # @return [String]
    def admin_config_path
      File.join(@system_root, "#{@admin_config_file_name}.yaml")
    end

    # Get's the path to the system info file
    # @return [String]
    def system_info_path
      File.join(@system_root, "#{@system_info_file_name}.yaml")
    end
  end
end
