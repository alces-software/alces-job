# frozen_string_literal: true

require_relative '../converters/memory_converter'
require_relative '../converters/time_converter'
require_relative 'integer_directive_validator'
require_relative 'sbatch_directive_validator'
require_relative '../sys_limits/sys_limits'
require_relative '../sys_info/sys_info'
require_relative '../paths/paths'

module AlcesJob
  module Services
    class SlurmScriptValidator
      attr_reader :errors, :warnings

      def initialize(file_path)
        @file_path = file_path
        @errors = []
        @warnings = []
        @system_info = SysInfo.load_info(Paths.new.system_info_path)
      end

      def validate?
        lines = File.readlines(@file_path, chomp: true)
        validate_shebang(lines)
        sbatch_lines = lines.select { |line| line.start_with?('#SBATCH') }
        validate_sbatch_lines_exist(sbatch_lines)
        validate_duplicate_directives(sbatch_lines)
        SbatchDirectiveValidator.validate_directives(sbatch_lines, errors)
        IntegerDirectiveValidator.validate(sbatch_lines, errors)
        validate_memory(sbatch_lines)
        validate_time(sbatch_lines)
        errors.empty?
      end

      private

      def validate_shebang(lines)
        return if lines[0] == '#!/bin/bash'

        errors << 'Missing shebang, spelt incorrectly, or unsupported. Expected: #!/bin/bash.'
      end

      def validate_sbatch_lines_exist(sbatch_lines)
        return unless sbatch_lines.empty?

        errors << 'No #SBATCH directives found.'
      end

      def validate_duplicate_directives(sbatch_lines)
        directive_names = sbatch_lines.map do |line|
          line.split[1]&.split('=')&.first
        end

        duplicates = directive_names
          .compact
          .select { |name| directive_names.count(name) > 1 }
          .uniq
        duplicates.each do |duplicate|
          errors << "Duplicate directive found: #{duplicate}."
        end
      end

      def validate_memory(sbatch_lines)
        mem_value = directive_value(sbatch_lines, '--mem')

        if mem_value
          requested_memory_mb = MemoryConverter.to_mb(mem_value)
          max_memory_mb = AlcesJob::Services::SystemLimits.max_memory_mb(@system_info)

          if requested_memory_mb.nil?
            errors << "Invalid memory format: #{mem_value}. Expected formats like 4G, 500M, etc."
          elsif requested_memory_mb > max_memory_mb
            errors << "Requested memory (#{requested_memory_mb} MB) exceeds the maximum allowed (#{max_memory_mb} MB)."
          end
        else
          warnings << 'No --mem directive found.'
        end
      end

      def validate_time(sbatch_lines)
        time_value = directive_value(sbatch_lines, '--time')
        partition_name = directive_value(sbatch_lines, '--partition')

        max_time_seconds = AlcesJob::Services::SystemLimits.time_limit_seconds(
          @system_info,
          partition_name
        )

        if time_value
          requested_time_seconds = TimeConverter.to_seconds(time_value)

          if requested_time_seconds.nil?
            errors << 'Invalid time format. Expected HH:MM:SS or D-HH:MM:SS.'
          elsif requested_time_seconds > max_time_seconds
            errors << "Requested time (#{requested_time_seconds} seconds) exceeds the maximum allowed (#{max_time_seconds} seconds) for partition #{partition_name || 'default'}."
          end
        else
          warnings << 'No --time directive found.'
        end
      end

      def directive_value(sbatch_lines, directive)
        sbatch_lines.each do |line|
          match = line.match(/\A#SBATCH\s+#{Regexp.escape(directive)}(?:=|\s+)(.+)\z/)
          return match[1].strip if match
        end
        nil
      end
    end
  end
end
