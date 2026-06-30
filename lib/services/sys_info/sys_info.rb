# frozen_string_literal: true

require 'open3'
require 'yaml'

require_relative '../paths/paths'

module AlcesJob
  module Services
    module SysInfo
      # Load system information from file if available or grabs info
      # @return [Hash{nodes: Array<Hash>, partitions: Array<Hash>, packages: Array<String>, gpu_total: Integer}]
      def self.load_info
        user_path = Paths.new.user_system_info_path
        return YAML.load_file(user_path) if File.exist?(user_path)

        admin_path = Paths.new.admin_system_info_path
        return YAML.load_file(admin_path) if File.exist?(admin_path)

        all_info
      end

      # Gets all system information
      # @return [Hash{nodes: Array<Hash>, partitions: Array<Hash>, packages: Array<String>, gpu_total: Integer}]
      def self.all_info
        {
          partitions: partition_info,
          packages: package_info
        }
      end

      # Returns a summary of available Slurm partitions.
      # @return [Hash{String => {
      #   default: Boolean,
      #   max_memory_mb: Integer,
      #   max_cpu_cores: Integer,
      #   max_gpus: Integer,
      #   node_count: Integer,
      #   time_limit: String
      # }}]
      def self.partition_info
        stdout, _, status =
          Open3.capture3('sinfo -N -h -o "%P|%N|%m|%c|%G|%l"')

        return {} unless status.success?

        stdout.each_line.with_object({}) do |line, partitions|
          partition, _node, memory, cpus, gres, time_limit =
            line.strip.split('|', 6)

          partition.delete('*').split(',').each do |partition_name|
            partitions[partition_name] ||= {
              name: partition_name,
              default: partition.include?('*'),
              max_memory_mb: 0,
              max_cpu_cores: 0,
              max_gpus: 0,
              node_count: 0,
              time_limit:
                case time_limit
                when 'infinite'
                  '0-00:00:00'
                when /\A\d{2}:\d{2}:\d{2}\z/
                  "0-#{time_limit}"
                else
                  time_limit
                end
            }

            info = partitions[partition_name]

            info[:node_count] += 1
            info[:max_memory_mb] = [info[:max_memory_mb], memory.to_i].max
            info[:max_cpu_cores] = [info[:max_cpu_cores], cpus.to_i].max

            next if gres.to_s.empty? || gres == '(null)'

            clean_gres = gres.to_s.sub(/\(.+\)\z/, '')

            gpu_count =
              if clean_gres =~ /gpu:(?:[^:,\s]+:)?(\d+)/
                Regexp.last_match(1).to_i
              else
                0
              end

            info[:max_gpus] = [info[:max_gpus], gpu_count].max
          end
        end
      rescue Errno::ENOENT
        {}
      end

      # Gets a list of the names
      # @return [Hash]
      def self.package_info
        stdout, _, status = Open3.capture3('module -t avail 2>&1')

        return {} unless status.success?

        parsed = Hash.new { |h, k| h[k] = [] }
        category = nil

        stdout.lines.map(&:strip).reject(&:empty?).each do |line|
          line = line.strip
          next if line.empty?
          next if line.downcase == 'null'

          if line.end_with?(':')
            category = line.split('/').last.chop
            next
          end

          next if line.end_with?('/')

          name, version = line.split('/', 2)
          next if version.nil?

          version = version.split('-', 2).first

          next if parsed.values.any? do |category_hash|
            category_hash.any? { |v| v[:name] == name && v[:version] == version }
          end

          deprecated =
            line.downcase.include?('deprecated') ||
            line.downcase.include?('legacy') ||
            line.downcase.include?('old') ||
            line.downcase.include?('(deprecated)')

          parsed[category] << {
            name: name,
            version: version,
            deprecated: deprecated
          }
        end

        parsed
      rescue Errno::ENOENT
        {}
      end
    end
  end
end
