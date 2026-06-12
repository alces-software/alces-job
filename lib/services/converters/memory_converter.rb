# frozen_string_literal: true

module MemoryConverter
  def self.to_mb(memory)
    match = memory.strip.upcase.match(/\A(\d+(?:\.\d+)?)\s*(M|MB|G|GB|T|TB)?\z/)

    return nil unless match

    amount = match[1].to_f
    unit = match[2] || 'MB'

    case unit
    when 'M', 'MB'
      amount.ceil
    when 'G', 'GB'
      amount.ceil * 1024
    when 'T', 'TB'
      amount.ceil * 1024 * 1024

    end
  end
end
