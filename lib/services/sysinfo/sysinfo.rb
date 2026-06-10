# frozen_string_literal: true

module AlcesJob
  class SysInfo
    def getAllInfo
      node = getNodeInfo
      partition = getPartitionInfo
      package = getPackageInfo
      gpu = getGpuInfo

      {
        nodes: node,
        partitions: partition,
        packages: package,
        gpu_total: gpu
      }
    end

    def getNodeInfo
      # `sinfo -N -h -o "%N %c %m"`
      "node01 32 385024
      node02 32 385024
      node03 32 385024
      node04 32 385024
      node05 32 385024
      node06 32 385024
      node07 32 385024
      node08 32 385024
      node09 32 385024
      node10 32 385024
      node11 32 385024
      node12 32 385024
      node13 32 385024
      node14 32 385024
      node15 32 385024
      node16 32 385024"
        .lines
        .map do |line|
          node, cpus, mem = line.strip.split
          { node: node, cpus: cpus.to_i, memory: mem.to_i }
        end
    end

    def getPartitionInfo
      # `sinfo -o "%P %l" -h`
      "gpu-l40s 7-00:00:00
      gpu-h100 7-00:00:00"
        .lines
        .map do |line|
          part, time = line.strip.split
          { partition: part, time_limit: time }
        end
    end

    def getPackageInfo
      # `module avail 2>&1 | sed 's#/[^ ]*##g'`
      "test
      test2
      test3
      test4
      test5"
        .lines
        .map(&:strip)
    end

    def getGpuInfo
      # `scontrol show nodes | grep -o 'gpu:[^:]*:[0-9]*' | cut -d':' -f3 | paste -sd+ | bc`.strip.to_i
      '48'.strip.to_i
    end
  end
end
