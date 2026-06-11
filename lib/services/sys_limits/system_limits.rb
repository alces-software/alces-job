# frozen_string_literal: true

require_relative '../converters/time_converter'
require_relative '../converters/memory_converter'

require_relative '../sysinfo/sysinfo'

module AlcesJob
  module Services
    module SystemLimits
      DEFAULT_NODE_COUNT = 1
      DEFAULT_MEMORY_MB = 5000
      DEFAULT_TIME_SECONDS = 86_400
      DEFAULT_CPUS_PER_NODE = 4
      DEFAULT_GPUS_PER_NODE = 1

      def self.node_count(system_info)
        nodes = nodes_from(system_info)
        nodes || DEFAULT_NODE_COUNT if nodes.empty?

        nodes.length
      end

      def self.max_memory_mb(system_info)
        nodes = nodes_from(system_info)

        return DEFAULT_MEMORY_MB if nodes.empty?

        nodes.map { |node| node[:memory] || node['memory'] }.compact.max || DEFAULT_MEMORY_MB
      end

      def self.max_cpus_per_node(system_info)
        nodes = nodes_from(system_info)

        return DEFAULT_CPUS_PER_NODE if nodes.empty?

        nodes.map { |node| node[:cpus] || node['cpus'] }.compact.max || DEFAULT_CPUS_PER_NODE
      end

      def self.valid_partitions(system_info)
        partitions = partitions_from(system_info)

        partitions.map { |partition| partition[:partition] || partition['partition'] }.compact
      end

      def self.time_limit_seconds(system_info, partition_name = nil)
        partitions = partitions_from(system_info)

        return DEFAULT_TIME_SECONDS if partitions.empty?

        partition = find_partition(partitions, partition_name)

        time_limit = partition[:time_limit] || partition['time_limit']

        TimeConverter.to_seconds(time_limit.to_s) || DEFAULT_TIME_SECONDS
      end

      def self.gpu_total(system_info)
        return DEFAULT_GPU_TOTAL if system_info.nil?

        system_info[:gpu_total] || system_info['gpu_total'] || DEFAULT_GPU_TOTAL
      end

      def self.nodes_from(system_info)
        return [] if system_info.nil?

        system_info[:nodes] || system_info['nodes'] || []
      end

      def self.partitions_from(system_info)
        return [] if system_info.nil?

        system_info[:partitions] || system_info['partitions'] || []
      end

      def self.find_partition(partitions, partition_name)
        return partitions.first if partition_name.nil?

        partitions.find do |partition|
          name = partition[:partition] || partition['partition']

          name == partition_name
        end || partitions.first
      end
    end
  end
end
