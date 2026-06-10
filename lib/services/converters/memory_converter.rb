module MemoryConverter

    def self.to_mb(memory)
        match = memory.strip.upcase.match(/\A(\d+)\s*(K|KB|M|MB|G|GB|T|TB)\z/)

        return nil unless match 

        amount = match[1].to_i
        unit = match[2]

        case unit 
        when"M", "MB"
            amount
        when "G", "GB"
            amount * 1024 
        when "T", "TB"
            amount * 1024 * 1024
        end
    end
end
