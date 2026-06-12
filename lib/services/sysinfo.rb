# frozen_string_literal: true

require 'open3'
require 'yaml'

module AlcesJob
  module Services
    module SysInfo
      # Load system information from file if available or grabs info
      # @return [Hash{nodes: Array<Hash>, partitions: Array<Hash>, packages: Array<String>, gpu_total: Integer}]
      def self.load_info(config)
        return complete_info(YAML.load_file(config['admin_config_file'])) if File.exist?(config['admin_config_file'])

        all_info
      end

      # Gets all system information
      # @return [Hash{nodes: Array<Hash>, partitions: Array<Hash>, packages: Array<String>, gpu_total: Integer}]
      def self.all_info
        complete_info(actual_info)
      end

      def self.actual_info
        {
          nodes: node_info,
          partitions: partition_info,
          packages: package_info,
          gpu_total: gpu_info
        }
      end

      def self.slurm_available?(info = nil)
        info ||= actual_info
        info[:nodes].is_a?(Array) && !info[:nodes].empty? &&
          info[:partitions].is_a?(Array) && !info[:partitions].empty?
      end

      def self.complete_info(info)
        return default_info unless info.is_a?(Hash)

        {
          nodes: info[:nodes] || info['nodes'] || default_nodes,
          partitions: info[:partitions] || info['partitions'] || default_partitions,
          packages: info[:packages] || info['packages'] || default_packages,
          gpu_total: info[:gpu_total] || info['gpu_total'] || 0
        }
      end

      def self.default_info
        {
          nodes: default_nodes,
          partitions: default_partitions,
          packages: default_packages,
          gpu_total: 0
        }
      end

      def self.default_nodes
        [{ node: 'local', cpus: 4, memory: 5_000 }]
      end

      def self.default_partitions
        [{ partition: 'default', time_limit: '0-07:00:00', default: true }]
      end

      def self.default_packages
        []
      end

      # Gets the node information
      # @return [Array<{node: String, cpus: Integer, memory: Integer}>, nil]
      def self.node_info
        stdout, _, status = Open3.capture3('sinfo -N -h -o "%N %c %m"')

        return nil unless status.success?

        stdout
          .lines
          .map do |line|
            node, cpus, mem = line.strip.split
            { node: node, cpus: cpus.to_i, memory: mem.to_i }
          end
      rescue Errno::ENOENT
        nil
      end

      # Gets partition information
      # @return [Array<{partition: String, time_limit: String, default: Boolean}>, nil]
      def self.partition_info
        stdout, _, status = Open3.capture3('sinfo -o "%P %l" -h')

        return nil unless status.success?

        stdout.lines.map do |line|
          partition, time_limit = line.strip.split(/\s+/, 2)

          normalized_time_limit =
            case time_limit
            when 'infinite'
              '0-00:00:00'
            when /\A\d{2}:\d{2}:\d{2}\z/
              "0-#{time_limit}"
            else
              time_limit
            end

          {
            partition: partition.delete('*'),
            time_limit: normalized_time_limit,
            default: partition.include?('*')
          }
        end
      rescue Errno::ENOENT
        nil
      end

      # Gets a list of the names
      # @return [Array<String>, nil]
      def self.package_info
        stdout, _, status = Open3.capture3('module avail')

        return nil unless status.success?

        stdout.lines.map do |line|
          line.gsub(%r{/[^ ]*}, '').strip
        end
      rescue Errno::ENOENT
        nil
      end

      # Gets the gpu information and returns a count of how many there are
      # @return [Integer]
      def self.gpu_info
        stdout, _, status = Open3.capture3("scontrol show nodes | grep -o 'gpu:[^:]*:[0-9]*' | cut -d':' -f3 | paste -sd+ | bc")

        return 0 unless status.success?

        stdout.strip.to_i
      rescue Errno::ENOENT
        0
      end
    end
  end
end
