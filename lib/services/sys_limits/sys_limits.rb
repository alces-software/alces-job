# frozen_string_literal: true

require_relative '../converters/time_converter'
require_relative '../converters/memory_converter'

module AlcesJob
  module Services
    module SystemLimits
      DEFAULT_NODE_COUNT = 1
      DEFAULT_MEMORY_MB = 20000
      DEFAULT_TIME_SECONDS = 604_800 # 7 days
      DEFAULT_CPUS_PER_NODE = 4
      DEFAULT_GPUS_PER_NODE = 1

      class << self
        # Get node count for a partition
        # @param [Hash] system_info
        # @param [String, nil] partition_name
        # @return [Integer]
        def node_count(system_info, partition_name = nil)
          partition = safe_partition(system_info, partition_name)
          to_int(partition[:node_count] || partition['node_count'], DEFAULT_NODE_COUNT)
        end

        # Get max memory (MB) for a partition
        # @param [Hash] system_info
        # @param [String, nil] partition_name
        # @return [Integer]
        def max_memory_mb(system_info, partition_name = nil)
          partition = safe_partition(system_info, partition_name)
          to_int(partition[:max_memory_mb] || partition['max_memory_mb'], DEFAULT_MEMORY_MB)
        end

        # Get max CPU cores for a partition
        # @param [Hash] system_info
        # @param [String, nil] partition_name
        # @return [Integer]
        def max_cpus(system_info, partition_name = nil)
          nodes = nodes_from(system_info)
          return DEFAULT_CPUS_PER_NODE if nodes.empty?

          partition = safe_partition(system_info, partition_name)
          to_int(partition[:max_cpu_cores] || partition['max_cpu_cores'], DEFAULT_CPUS_PER_NODE)
        end

        # List all valid partition names
        # @param [Hash] system_info
        # @return [Array<String>]
        def valid_partitions(system_info)
          partitions = partitions_from(system_info)

          partitions.filter_map do |partition|
            partition[:partition] || partition['partition']
          end
        end

        # Get time limit (seconds) for a partition
        # @param [Hash] system_info
        # @param [String, nil] partition_name
        # @return [Integer]
        def time_limit_seconds(system_info, partition_name = nil)
          partitions = partitions_from(system_info)

          return DEFAULT_TIME_SECONDS if partitions.empty? || partition_name.nil?

          partition = safe_partition(system_info, partition_name)
          time_limit = partition[:time_limit] || partition['time_limit']

          seconds = TimeConverter.to_seconds(time_limit.to_s)
          to_int(seconds, DEFAULT_TIME_SECONDS)
        end

        # Get total GPUs available for a partition
        # @param [Hash] system_info
        # @param [String, nil] partition_name
        # @return [Integer]
        def gpu_total(system_info, partition_name = nil)
          partitions = partitions_from(system_info)

          return DEFAULT_GPUS_PER_NODE if system_info.nil? || partition_name.nil? || partitions.empty?

          partition = safe_partition(system_info, partition_name)
          to_int(partition[:gpu_total] || partition['gpu_total'], DEFAULT_GPUS_PER_NODE)
        end

        private

        # Extract partitions from system info
        # @param [Hash] system_info
        # @return [Array<Hash>]
        def partitions_from(system_info)
          return [] if system_info.nil?

          system_info[:partitions] || system_info['partitions'] || []
        end

        # Find a partition by name (or fallback to first)
        # @param [Array<Hash>] partitions
        # @param [String, nil] partition_name
        # @return [Hash]
        def find_partition(partitions, partition_name)
          return {} unless partitions.is_a?(Array)

          return partitions.first if partition_name.nil?

          partitions.find do |partition|
            next false unless partition.is_a?(Hash)

            name = partition[:name] || partition['name']
            name == partition_name
          end || {}
        end

        # Safe wrapper around find_partition
        def safe_partition(system_info, partition_name)
          partitions = partitions_from(system_info)
          find_partition(partitions, partition_name)
        end

        # Strict integer coercion with fallback
        # @param [Object] value
        # @param [Integer] default
        # @return [Integer]
        def to_int(value, default)
          Integer(value)
        rescue ArgumentError, TypeError
          default
        end

        # Extract nodes list from system info
        # @param [Hash] system_info
        # @return [Array]
        def nodes_from(system_info)
          return [] if system_info.nil?

          system_info[:nodes] || system_info['nodes'] || []
        end
      end
    end
  end
end
