# frozen_string_literal: true

module AlcesJob
  module Services
    module TimeConverter
      # Converts a time to seconds
      # @param [String] time
      # @return [Integer]
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

      # Converts a slurm time to seconds
      # @param [String] time
      # @return [Integer]
      def self.slurm_time_to_seconds(time)
        return nil if time.nil?

        time = time.strip
        return nil if time.empty?

        days = 0

        if time.include?('-')
          day_part, time_part = time.split('-', 2)

          return nil unless day_part.match?(/\A\d+\z/)

          days = day_part.to_i
        else
          time_part = time
        end
        parts = time_part.split(':')

        return nil unless parts.length == 3
        return nil unless parts.all? { |part| part.match?(/\A\d+\z/) }

        hours, minutes, seconds = parts.map(&:to_i)

        return nil unless hours.between?(0, 23)
        return nil unless minutes.between?(0, 59)
        return nil unless seconds.between?(0, 59)

        (days * 86_400) + (hours * 3_600) + (minutes * 60) + seconds
      end

      # compares an input time against a max time to see if its allowed or not
      # @param [Integer] time
      # @param [Integer] max_time
      # @return [Boolean]
      def self.valid_slurm_time?(time, max_time)
        input_seconds = slurm_time_to_seconds(time)
        max_seconds = slurm_time_to_seconds(max_time)

        return false if input_seconds.nil?
        return false if max_seconds.nil?

        return true if max_seconds.zero?

        input_seconds.positive? && input_seconds <= max_seconds
      end

      # Normalises a slurm time so they match
      # @param [String | Integer] time
      # @return [String]
      def self.normalise_slurm_time(time)
        if time.is_a?(Integer)
          days = time / 86_400
          remainder = time % 86_400

          hours = remainder / 3600
          remainder %= 3600

          minutes = remainder / 60
          seconds = remainder % 60

          return format(
            '%<days>d-%<hours>02d:%<minutes>02d:%<seconds>02d', days: days, hours: hours, minutes: minutes, seconds: seconds
          )
        end

        time_string = time.to_s

        return time_string if time_string.match?(/^\d+-\d{2}:\d{2}:\d{2}$/)

        return "0-#{time_string}" if time_string.match?(/^\d{2}:\d{2}:\d{2}$/)

        time_string
      end
    end
  end
end
