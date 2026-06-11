# frozen_string_literal: true

module TimeConverter
  def self.to_seconds(time_value)
    match = time_value.strip.match(/\A(?:(\d+)-)?(\d{1,2}):([0-5]\d):([0-5]\d)\z/)

    return nil unless match

    days = match[1].to_i
    hours = match[2].to_i
    minutes = match[3].to_i
    seconds = match[4].to_i

    return nil if hours > 23

    total_seconds = seconds + (minutes * 60) + (hours * 3600) + (days * 86_400)
  end
end
