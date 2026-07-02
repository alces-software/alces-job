# frozen_string_literal: true

require 'xdg'

require_relative '../config_manager/config_manager'

module AlcesJob
  module Services
    class Paths
      def initialize
        @xdg = XDG.new
        @system_root = '/etc/alces-job'
        @system_info_file_name = 'admin-system-info'
        @user_system_info_file_name = 'user-system-info'
        @admin_config_file_name = 'admin-config'
        @user_config_file_name = 'user-config'
      end

      # Job

      # Gets the path to the users job dir
      # @return [String]
      def user_job_dir
        config = ConfigManager.load_config

        config.dig('tracking', 'path') || @xdg.config_home.join('alces-job', 'tracking').to_s
      end

      # Profile

      # Gets the path to the users profile dir
      # @return [String]
      def user_profile_dir
        @xdg.config_home.join('alces-job', 'profiles').to_s
      end

      # Gets the path to a user specific profile
      # @param [String] profile_name
      # @return [String]
      def user_profile_path(profile_name)
        File.join(user_profile_dir, "#{profile_name}.yaml").to_s
      end

      # Template

      # Gets the path to the users templates dir
      # @return [String]
      def user_template_dir
        @xdg.config_home.join('alces-job', 'templates').to_s
      end

      # Gets the path to the user template specified
      # @param [String] template_name
      # @return [string]
      def user_template_path(template_name)
        File.join(user_template_dir, "#{template_name}.erb").to_s
      end

      # Gets the path to the admin template dir
      # @return [String]
      def admin_template_dir
        File.join(@system_root, 'templates').to_s
      end

      # Gets the path to the admin template specified
      # @param [String] template_name
      # @return [String]
      def admin_template_path(template_name)
        File.join(admin_template_dir, "#{template_name}.erb").to_s
      end

      # Config

      # Gets the path to the users config file
      # @return [String]
      def user_config_path
        @xdg.config_home.join('alces-job', "#{@user_config_file_name}.yaml").to_s
      end

      # Gets the path to the admin config file
      # @return [String]
      def admin_config_path
        File.join(@system_root, "#{@admin_config_file_name}.yaml").to_s
      end

      # System

      # Gets the path to the system info file
      # @return [String]
      def admin_system_info_path
        File.join(@system_root, "#{@system_info_file_name}.yaml").to_s
      end

      # Gets the path to the system info file
      # @return [String]
      def user_system_info_path
        @xdg.config_home.join('alces-job', "#{@user_system_info_file_name}.yaml").to_s
      end

      # Completion

      # Get's the path to the users .bashrc
      # @return [String]
      def user_bashrc_path
        File.join(Dir.home, '.bashrc').to_s
      end

      # Get's the directory for where the completion script is stored user specific
      # @return [String]
      def user_bash_completion_dir
        File.join(Dir.home, '.bash_completion.d').to_s
      end

      # Get's the path the cli's completion file which is user specific
      # @return [String]
      def user_bash_completion_path
        File.join(Dir.home, '.bash_completion.d', 'alces-job').to_s
      end

      # Get's the directory for where the completion script is stored system wide
      # @return [String]
      def system_bash_completion_dir
        File.join('/etc', '.bash_completion.d').to_s
      end

      # Get's the path the cli's completion file which is system wide
      # @return [String]
      def system_bash_completion_path
        File.join('/etc', '.bash_completion.d', 'alces-job').to_s
      end
    end
  end
end
