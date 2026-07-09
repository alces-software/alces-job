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

      # Gets a list of the packages
      # @return [Hash]
      def self.package_info
        parsed = {}

        case detect_module_manager
        when :lmod
          # Is recursive and will handle modules within modules
          stdout, _, status = Open3.capture3("module -t spider  2>&1 | grep -E '^/|^$'")

          return parsed unless status.success?

          stdout.lines.map(&:strip).reject(&:empty?).each do |line|
            next if line.end_with?('/')
            next if line.downcase == 'null'

            parts = line.split('/')
            name = parts.first
            version = if parts[2].to_s.downcase == 'none-none'
                        parts[1]
                      else
                        parts[1, 2].join('/')
                      end

            deprecated =
              line.downcase.include?('deprecated') ||
              line.downcase.include?('legacy') ||
              line.downcase.include?('old')

            mod_out, _, status = Open3.capture3("bash -lc \"module show #{line} 2>&1\"")

            description = nil
            category = nil

            if status.success?
              description = mod_out[/whatis\("description:\s*(.*?)"\)/i, 1] ||
                            mod_out[/description:\s*(.*)/i, 1]
              description = description&.strip

              category = mod_out[/whatis\("category:\s*(.*?)"\)/i, 1]
              category = category&.strip
            end

            description ||= 'No description available'
            category ||= line.split('/').first

            parsed[category] ||= []

            next unless exists.empty?

            parsed[category] << {
              full_name: line,
              name: name,
              version: version,
              description: description,
              deprecated: deprecated
            }
          end
        when :environment_modules
          # Isn't recursive at the moment and cant get modules within modules
          stdout, _, status = Open3.capture3("module -t avail 2>&1 | grep -vE '^/|^$'")

          return parsed unless status.success?

          stdout.lines.map(&:strip).reject(&:empty?).each do |line|
            next if line.end_with?('/')
            next if line.downcase == 'null'

            parts = line.split('/')
            name = parts.first
            version = if parts[2].to_s.downcase == 'none-none'
                        parts[1]
                      else
                        parts[1, 2].join('/')
                      end

            deprecated =
              line.downcase.include?('deprecated') ||
              line.downcase.include?('legacy') ||
              line.downcase.include?('old')

            mod_out, _, status = Open3.capture3("bash -lc \"module show #{line} 2>&1\"")

            description = nil
            category = nil

            if status.success?
              description = mod_out[/whatis\("description:\s*(.*?)"\)/i, 1] ||
                            mod_out[/description:\s*(.*)/i, 1]
              description = description&.strip

              category = mod_out[/whatis\("category:\s*(.*?)"\)/i, 1]
              category = category&.strip
            end

            description ||= 'No description available'
            category ||= line.split('/').first

            parsed[category] ||= []

            exists = parsed[category].filter do |filter|
              filter['full_name'] == line
            end

            next unless exists.empty?

            parsed[category] << {
              full_name: line,
              name: name,
              version: version,
              description: description,
              deprecated: deprecated
            }
          end
        else
          puts "\nEither no or an unsupported module manager was detected\n"
        end

        parsed
      rescue Errno::ENOENT
        {}
      end

      # Detects what's being used to manager modules
      # @return [Symbol]
      def self.detect_module_manager
        return :lmod if ENV['LMOD_VERSION']

        version = `bash -lc 'module --version 2>&1'`

        return :lmod if version.match?(/Lmod/i)
        return :environment_modules if version.match?(/Modules/i)

        :none
      end
    end
  end
end
