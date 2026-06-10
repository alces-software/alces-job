# frozen_string_literal: true

require 'open3'

module AlcesJob
  module SysInfo
    def self.getAllInfo
      {
        nodes: getNodeInfo,
        partitions: getPartitionInfo,
        packages: getPackageInfo,
        gpu_total: getGpuInfo
      }
    end

    def self.getNodeInfo
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

    def self.getPartitionInfo
      stdout, _, status = Open3.capture3('sinfo -o -h "%P %l"')

      return nil unless status.success?

      stdout
        .lines
        .map do |line|
          part, time = line.strip.split
          { partition: part, time_limit: time }
        end
    rescue Errno::ENOENT
      nil
    end

    def self.getPackageInfo
      stdout, _, status = Open3.capture3('module avail')

      return nil unless status.success?

      stdout.lines.map do |line|
        line.gsub(%r{/[^ ]*}, '').strip
      end
    rescue Errno::ENOENT
      nil
    end

    def self.getGpuInfo
      stdout, _, status = Open3.capture3("scontrol show nodes | grep -o 'gpu:[^:]*:[0-9]*' | cut -d':' -f3 | paste -sd+ | bc`")

      return 0 unless status.success?

      stdout.strip.to_i
    rescue Errno::ENOENT
      0
    end
  end
end
