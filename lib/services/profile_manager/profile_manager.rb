# frozen_string_literal: true

require 'yaml'
require 'pastel'

require_relative '../paths/paths'

module AlcesJob
  module Services
    class ProfileManager
      attr_reader :profile, :output

      # Loads the profile and adds it to the options
      # @param [String] profile_name
      # @param [Hash] options
      # @return [Hash]
      def initialize(profile_name, options)
        pastel = Pastel.new

        profile = YAML.load_file(AlcesJob::Services::Paths.new.user_profile_path(profile_name.strip)) || {}

        @output = []

        options_keys = options.keys
        profile.each_key do |key|
          if options_keys.include?(key)
            @output.push(pastel.yellow("Ignoring profile flag ~ #{key}"))
          else
            @output.push(pastel.green("Loaded profile flag ~ #{key}"))
          end
        end

        @profile = profile.merge(options)
      end
    end
  end
end
