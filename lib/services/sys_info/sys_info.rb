# frozen_string_literal: true

require 'open3'
require 'yaml'

require_relative '../paths/paths'

module AlcesJob
  module Services
    module SysInfo
      class << self
        # Load system information from file if available or grabs info
        # @return [Hash{nodes: Array<Hash>, partitions: Array<Hash>, packages: Array<String>, gpu_total: Integer}]
        def load_info
          user_path = Paths.new.user_system_info_path
          return YAML.load_file(user_path) if File.exist?(user_path)

          admin_path = Paths.new.admin_system_info_path
          return YAML.load_file(admin_path) if File.exist?(admin_path)

          all_info
        end

        # Gets all system information
        # @return [Hash{nodes: Array<Hash>, partitions: Array<Hash>, packages: Array<String>, gpu_total: Integer}]
        def all_info
          {
            partitions: partition_info,
            packages: package_info,
            max_array_size: max_array_size
          }
        end

        # Gets the max array size for the system
        # @return [Integer]
        def max_array_size
          stdout, _, status =
            Open3.capture3('scontrol show config | grep MaxArraySize')

          return 1001 unless status.success?

          stdout.split('=').last.strip.to_i
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
        def partition_info
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
        def package_info
          parsed = {}
          module_manager = detect_module_manager

          case module_manager
          when :lmod
            get_lmod_modules(parsed, {})
          when :environment_modules
            get_environment_modules_modules(parsed, {})
          end
          queue = []
          processed = Set.new
          parsed.each_value do |packages|
            queue.concat(packages)
          end

          until queue.empty?
            package = queue.shift

            next if processed.include?(package[:full_name])

            processed << package[:full_name]

            before = parsed.values.flatten.to_set { |p| p[:full_name] }

            case module_manager
            when :lmod
              get_lmod_modules(parsed, package)
            when :environment_modules
              get_environment_modules_modules(parsed, package)
            end

            parsed.values.flatten.each do |new_package|
              next if before.include?(new_package[:full_name])

              queue << new_package
            end
          end

          parsed
        rescue Errno::ENOENT
          {}
        end

        private

        # Detects what's being used to manager modules
        # @return [Symbol]
        def detect_module_manager
          return :lmod if ENV['LMOD_VERSION']

          version = `bash -lc 'module --version 2>&1'`

          return :lmod if version.match?(/Lmod/i)
          return :environment_modules if version.match?(/Modules/i)

          :none
        end

        # Get's all lmod modules  and if a module to load is provided it finds all of its children
        # @param [Hash] parsed
        # @param [String] to_load
        # @return [Hash]
        def get_lmod_modules(parsed, module_to_load)
          avail_command = +''
          module_to_load[:dependency]&.each do |dep|
            avail_command <<= "module load #{dep} && "
          end
          avail_command <<= "module load #{module_to_load[:full_name]} && " unless module_to_load.nil?
          avail_command <<= "module -t avail 2>&1 | grep -vE '^/|^$'"
          avail_command <<= ' && module purge' unless module_to_load.nil?

          stdout, _, status = Open3.capture3(avail_command)

          return parsed unless status.success?

          stdout.lines.map(&:strip).grep_v('').each do |line|
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

            show_command = +''
            module_to_load[:dependency]&.each do |dep|
              show_command <<= "module load #{dep} && "
            end
            show_command <<= "module load #{module_to_load[:full_name]} && " unless module_to_load.nil?
            show_command <<= "bash -lc \"module show #{line} 2>&1\""
            show_command <<= ' && module purge' unless module_to_load.nil?

            mod_out, _, status = Open3.capture3(show_command)

            description = nil
            category = nil

            if status.success?
              description = mod_out[/whatis\s*\(\s*["'](.*?)["']\s*\)/m, 1] ||
                            mod_out[/^Description:\s*\n(.*?)(?=^\w[\w ]*:\s*|\z)/m, 1]
              description = description&.sub(/description:/i, '')&.strip

              category = mod_out[/whatis\("category:\s*(.*?)"\)/i, 1]
              category = category&.strip

              if version.empty?
                version = mod_out[/setenv\s*\{\s*["'](?:GCC_)?VERSION["']\s*,\s*["'](.*?)["']\s*\}/i, 1] ||
                          mod_out[/whatis\s*\(\s*["'].*?([0-9]+\.[0-9]+(?:\.[0-9]+)?).*?["']\s*\)/m, 1] ||
                          mod_out[/:(\d+\.\d+(?:\.\d+)?)\s*$/m, 1] ||
                          mod_out[/version:\s*(.*)/i, 1]
                version = version&.strip
              end
            end

            description ||= 'No description available'
            category ||= line.split('/').first
            version ||= nil

            parsed[category] ||= []

            next if parsed[category].any? { |filter| filter[:full_name] == line }

            dependency = []
            unless module_to_load.empty?
              dependency << module_to_load[:full_name]
              module_to_load[:dependency]&.each do |dep|
                dependency << dep
              end
            end

            parsed[category] << {
              full_name: line,
              name: name,
              version: version,
              description: description,
              deprecated: deprecated,
              dependency: dependency
            }
          end

          parsed
        end

        # Get's all environment modules modules and if a module to load is provided it finds all of its children
        # @param [Hash] parsed
        # @param [String] to_load
        # @return [Hash]
        def get_environment_modules_modules(parsed, module_to_load)
          avail_command = +''
          avail_command <<= "module load #{module_to_load[:full_name]} && " unless module_to_load.empty?
          avail_command <<= "module -t avail 2>/dev/null | grep -vE '^/|^$'"
          avail_command <<= ' && module purge' unless module_to_load.empty?

          stdout, _, status = Open3.capture3(avail_command)

          return parsed unless status.success?

          stdout.lines.map(&:strip).grep_v('')
            .grep_v(->(l) { l.start_with?('+') })
            .grep_v(/^\s*[\w ]+\s*=/)
            .grep_v(/This module will/)
            .grep_v(/check-out last/)
            .grep_v(/get-modules/)
            .grep_v(/Loading/)
            .each do |line|
            next if line.end_with?('/')
            next if line.downcase == 'null'
            next if line.strip.empty?

            line = line.sub(/\s*<[^>]*L>\z/i, '')

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

            show_command = +''
            show_command <<= "module load #{module_to_load[:full_name]} && " unless module_to_load.empty?
            show_command <<= "bash -lc \"module show #{line} 2>&1\""
            show_command <<= ' && module purge' unless module_to_load.empty?

            mod_out, _, status = Open3.capture3(show_command)

            mod_out = mod_out.lines.reject { |line| line.include?('Loading') || line.include?('Loading requirement:') }.join

            description = nil
            category = nil

            if status.success?
              description = mod_out[/module-whatis\s+\{(.*?)\}/m, 1] ||
                            mod_out[/module-whatis\s+(.*)/, 1]
              description = description&.strip

              category = mod_out[/module-whatis\s+\{[Cc]ategory:\s*(.*?)\}/, 1]
              category = category&.strip

              if version.empty?
                version =
                  mod_out[%r{^.*/([^/:\s]+)/(\d+\.\d+(?:\.\d+)*):\s*$}m, 2] ||
                  mod_out[/module-whatis\s+\{.*?([0-9]+\.[0-9]+(?:\.[0-9]+)*)/, 1] ||
                  mod_out[/version:\s*(.*)/i, 1]
                version = version&.strip
              end
            end

            description ||= 'No description available'
            category ||= line.split('/').first

            dependency = []
            dep_out, _, status = Open3.capture3("module load #{line} && module purge")

            dep_out = dep_out.lines.grep(/Loading requirement:/).join.strip

            unless dep_out.empty?
              dep_out.split(':').last.split.each do |dep|
                dependency << dep
              end
            end

            parsed[category] ||= []

            next if parsed[category].any? { |package| package[:full_name] == line }

            parsed[category] << {
              full_name: line,
              name: name,
              version: version,
              description: description,
              deprecated: deprecated,
              dependency: dependency
            }
          end

          parsed
        end
      end
    end
  end
end
