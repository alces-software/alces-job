# frozen_string_literal: true

require 'open3'

module AlcesJob
  module SysInfo
    def self.all_info
      {
        nodes: node_info,
        partitions: package_info,
        packages: package_info,
        gpu_total: gpu_info
      }
    end

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

    def self.partition_info
      stdout, _, status = Open3.capture3('sinfo -o "%P %l" -h')

      return nil unless status.success?

      stdout
        .lines
        .map do |line|
          part, time = line.strip.split
          { partition: part.delete('*'), time_limit: time }
        end
    rescue Errno::ENOENT
      nil
    end

    def self.package_info
      stdout, _, status = Open3.capture3('module avail')

      return nil unless status.success?

      stdout.lines.map do |line|
        line.gsub(%r{/[^ ]*}, '').strip
      end
    rescue Errno::ENOENT
      nil
    end

    def self.gpu_info
      stdout, _, status = Open3.capture3("scontrol show nodes | grep -o 'gpu:[^:]*:[0-9]*' | cut -d':' -f3 | paste -sd+ | bc`")

      return 0 unless status.success?

      stdout.strip.to_i
    rescue Errno::ENOENT
      0
    end
  end
end
