# frozen_string_literal: true

require 'open3'
require 'yaml'

module AlcesJob
  module Services
    module SysInfo
      # Load system information from file if available or grabs info
      # @return [Hash{nodes: Array<Hash>, partitions: Array<Hash>, packages: Array<String>, gpu_total: Integer}]
      def self.load_info(config)
        return YAML.load_file(config['admin_config_file']) if File.exist?(config['admin_config_file'])

        all_info
      end

      # Gets all system information
      # @return [Hash{nodes: Array<Hash>, partitions: Array<Hash>, packages: Array<String>, gpu_total: Integer}]
      def self.all_info

        live_info ={
          nodes: node_info,
          partitions: partition_info,
          packages: package_info,
          gpu_total: gpu_info
        }
        return live_info if live_info[:nodes] && live_info[:partitions]

        YAML.load_file('/Users/ab/Documents/alces-job/testData.yaml')
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
