module TimeConverter

    def self.to_seconds(time_value)
        match = time_value.strip.match(/\A(?:(\d+)-)?(\d{1,2}):([0-5]\d):([0-5]\d)\z/)

        return nil unless match
    
        days = match[1].to_i
        hours = match[2].to_i
        minutes = match[3].to_i
        seconds = match[4].to_i

        total_seconds = seconds + (minutes * 60) + (hours * 3600) + (days * 86400)
    end
end