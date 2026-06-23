# frozen_string_literal: true

module AlcesJob
  module Services
    module TimeConverter
      # Converts a time to seconds
      # @param [String] time
      # @return [String]
      def self.to_seconds(time)
        match = time.strip.match(/\A(?:(\d+)-)?(\d{1,2}):([0-5]\d):([0-5]\d)\z/)

        return nil unless match

        days = match[1].to_i
        hours = match[2].to_i
        minutes = match[3].to_i
        seconds = match[4].to_i

        return nil if hours > 23

        seconds + (minutes * 60) + (hours * 3600) + (days * 86_400)
      end

      # Converts a time to human readable
      # @param [String] time
      # @return [String]
      def self.to_human_readable(time)
        return 'unknown' if time.nil?

        days, hours, minutes, seconds =
          time.strip.match(/\A(?:(\d+)-)?(\d+):(\d+):(\d+)\z/)
            &.captures
            &.map(&:to_i)

        parts = {
          days: days,
          hours: hours,
          minutes: minutes,
          seconds: seconds
        }.filter_map do |unit, value|
          "#{value} #{unit}" if value.positive?
        end

        parts.empty? ? '0 seconds' : parts.join(', ')
      end
    end
  end
end
