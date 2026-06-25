# frozen_string_literal: true

require_relative '../converters/time_converter'
require_relative '../converters/memory_converter'

module AlcesJob
  module Services
    module SystemLimits
      DEFAULT_NODE_COUNT = 1
      DEFAULT_MEMORY_MB = 5000
      DEFAULT_TIME_SECONDS = 604_800 # 7 days in seconds
      DEFAULT_CPUS_PER_NODE = 4
      DEFAULT_GPUS_PER_NODE = 1 # Hardcoded limits for now

      # Get's the node count from a partition
      # @param [Hash] system_info
      # @param [String] partition_name
      # @return [Integer]
      def self.node_count(system_info, partition_name = nil)
        partitions = partitions_from(system_info)

        return DEFAULT_NODE_COUNT if partitions.empty?

        partition = find_partition(partitions, partition_name)

        partition[:node_count] || partition['node_count']
      end

      # Get's the max memory of a partition
      # @param [Hash] system_info
      # @param [String] partition_name
      # @return [Integer]
      def self.max_memory_mb(system_info, partition_name = nil)
        partitions = partitions_from(system_info)

        return DEFAULT_MEMORY_MB if partitions.empty?

        partition = find_partition(partitions, partition_name)

        partition[:max_memory_mb] || partition['max_memory_mb'] || DEFAULT_MEMORY_MB
      end

      # Get's the max amount of cpus in a partition
      # @param [Hash] system_info
      # @param [String] partition_name
      # @return [Integer]
      def self.max_cpus(system_info, partition_name = nil)
        nodes = nodes_from(system_info)
        partitions = partitions_from(system_info)

        return DEFAULT_CPUS_PER_NODE if nodes.empty?

        partition = find_partition(partitions, partition_name)

        partition[:max_cpu_cores] || partition['max_cpu_cores'] || DEFAULT_CPUS_PER_NODE
      end

      # Get's all the valid partitions
      # @param [Hash] system_info
      # @return [Array]
      def self.valid_partitions(system_info)
        partitions = partitions_from(system_info)

        partitions.filter_map { |partition| partition[:partition] || partition['partition'] }
      end

      # Get's the time limit for a partition
      # @param [Hash] system_info
      # @param [String] partition_name
      # @return [Integer]
      def self.time_limit_seconds(system_info, partition_name = nil)
        partitions = partitions_from(system_info)

        return DEFAULT_TIME_SECONDS if partitions.empty? || partition_name.nil?

        partition = find_partition(partitions, partition_name)

        time_limit = partition[:time_limit] || partition['time_limit']

        TimeConverter.to_seconds(time_limit.to_s) || DEFAULT_TIME_SECONDS
      end

      # Get's the total amount of available gpus for a partition
      # @param [Hash] system_info
      # @param [String] partition_name
      # @return [Integer]
      def self.gpu_total(system_info, partition_name = nil)
        partitions = partitions_from(system_info)

        return DEFAULT_GPUS_PER_NODE if system_info.nil? || partition_name.nil? || partitions.empty?

        partition = find_partition(partitions, partition_name)

        partition[:gpu_total] || partition['gpu_total'] || DEFAULT_GPUS_PER_NODE
      end

      class << self
        private

        # Get's all the partitions from the system info
        # @param [Hash] system_info
        # @return [Array]
        def partitions_from(system_info)
          return [] if system_info.nil?

          system_info[:partitions] || system_info['partitions'] || []
        end

        # Finds a specific partition in an array of partitions
        # @param [Array] partitions
        # @param [String] partition_name
        # @return [Hash]
        def find_partition(partitions, partition_name)
          return partitions.first if partition_name.nil?

          partitions.find do |partition|
            name = partition[:partition] || partition['partition']

            name == partition_name
          end || partitions.first
        end
      end
    end
  end
end
