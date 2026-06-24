module AlcesJob
  module Services
    # Merges two hashes at a deep level
    # @param [Hash] hash1
    # @param [Hash] hash2
    # @return [Hash]
    def self.deep_merge(hash1, hash2)
      hash1.merge(hash2) do |_, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge(old_val, new_val)
        else
          new_val
        end
      end
    end
  end
end
