# frozen_string_literal: true

require 'open3'
require 'yaml'

module AlcesJob
  module Services
    module SysInfo
      # Load system information from file if available or grabs info
      # @return [Hash{nodes: Array<Hash>, partitions: Array<Hash>, packages: Array<String>, gpu_total: Integer}]
      def self.load_info(sysinfo_path)
        return YAML.load_file(sysinfo_path) if File.exist?(sysinfo_path)

        all_info
      end

      # Gets all system information
      # @return [Hash{nodes: Array<Hash>, partitions: Array<Hash>, packages: Array<String>, gpu_total: Integer}]
      def self.all_info
        {
          partitions: partition_info,
          packages: package_info,
          gpu_total: gpu_info
        }
      end

      # Gets partition information
      # @return [Array<{partition: String, time_limit: String, default: Boolean, nodes: Array<{name: String, cores: Integer, memory_mb: Integer}>}>]
      def self.partition_info
        partition_stdout, _, partition_status =
          Open3.capture3('sinfo -o "%P %l" -h')

        return [] unless partition_status.success?

        node_stdout, _, node_status =
          Open3.capture3('sinfo -N -o "%P %N %c %m" -h')

        return [] unless node_status.success?

        nodes_by_partition = Hash.new { |h, k| h[k] = [] }

        node_stdout.lines.each do |line|
          partition, node_name, cpus, memory = line.strip.split(/\s+/, 4)

          partition.delete('*').split(',').each do |part|
            nodes_by_partition[part] << {
              name: node_name,
              cores: cpus.to_i,
              memory_mb: memory.to_i
            }
          end
        end

        partition_stdout.lines.map do |line|
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

          partition_name = partition.delete('*')

          {
            partition: partition_name,
            time_limit: normalized_time_limit,
            default: partition.include?('*'),
            nodes: nodes_by_partition[partition_name]
          }
        end
      rescue Errno::ENOENT
        []
      end

      # Gets a list of the names
      # @return [Array<String>, nil]
      def self.package_info
        stdout, _, status = Open3.capture3('module avail')

        return [] unless status.success?

        stdout.lines.map do |line|
          line.gsub(%r{/[^ ]*}, '').strip
        end
      rescue Errno::ENOENT
        []
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
