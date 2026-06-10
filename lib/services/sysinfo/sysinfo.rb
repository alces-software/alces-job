module AlcesJob
  class SysInfo
    def getAllInfo
      node = getNodeInfo
      partition = getPartitionInfo
      # package = getPackageInfo
      # gpu = getGpuInfo

      {
        nodes: node,
        partitions: partition
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
          node, cpus, mem = line.split
          { node: node, cpus: cpus.to_i, memory: mem.to_i }
        end
    end

    def getPartitionInfo
      # `sinfo -o "%P %l" -h`
      "gpu-l40s 7-00:00:00
gpu-h100 7-00:00:00"
        .lines
        .map do |line|
          part, time = line.split
          { partition: part, timelimit: time }
        end
    end

    def getPackageInfo
      puts 'not implemented'
    end

    def getGpuInfo
      puts 'not implemented'
    end
  end
end
