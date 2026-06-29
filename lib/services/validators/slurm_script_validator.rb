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

      SUPPORTED_SHEBANGS = [
        '#!/bin/bash',
        '#!/usr/bin/bash',
        '#!/usr/bin/env bash'
      ].freeze
      VALID_FILENAME_PATTERN_SYMBOLS = [
        '%',
        'A',
        'a',
        'b',
        'J',
        'j',
        'N',
        'n',
        'r',
        'S',
        's',
        't',
        'u',
        'x'
      ].freeze

      VALID_MAIL_TYPES = %w[
        NONE
        BEGIN
        END
        FAIL
        REQUEUE
        ALL
        INVALID_DEPEND
        STAGE_OUT
        TIME_LIMIT
        TIME_LIMIT_90
        TIME_LIMIT_80
        TIME_LIMIT_50
        ARRAY_TASKS
        NONE
      ].freeze

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
        validate_job_name(sbatch_lines)
        validate_mutually_excllusive_directives(sbatch_lines)
        validate_memory(sbatch_lines)
        validate_time(sbatch_lines)
        validate_gres(sbatch_lines)
        validate_array(sbatch_lines)
        validate_dependency(sbatch_lines)
        validate_output(sbatch_lines)
        validate_account(sbatch_lines)
        validate_error(sbatch_lines)
        validate_partition(sbatch_lines)
        validate_mail_type(sbatch_lines)
        validate_mail_user(sbatch_lines)
        validate_sbatch_capital(lines)
        validate_duplicate_shebang(lines)
        validate_directives_before_commands(lines)
        validate_supported_shebang(lines)
        errors.empty?
      end

      private

      def validate_shebang(lines)
        if lines.empty?
          errors << 'Script is empty.'
          return
        end
        shebang_check = lines[0].sub(/\A#!\s*/, '#!').strip
        return if SUPPORTED_SHEBANGS.include?(shebang_check)

        errors << "Missing shebang, spelt incorrectly, or unsupported. Expected one of: #{SUPPORTED_SHEBANGS.join(',')}."
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
          partition_name = directive_value(sbatch_lines, '--partition')
          max_memory_mb = AlcesJob::Services::SystemLimits.max_memory_mb(@system_info, partition_name)

          if requested_memory_mb.nil?
            errors << "Invalid memory format: #{mem_value}. Expected formats like 4G, 500M, etc."
          elsif requested_memory_mb > max_memory_mb
            errors << "Requested memory (#{requested_memory_mb} MB) exceeds the maximum allowed (#{max_memory_mb} MB)."
          end
        else
          warnings << 'No --mem directive found.'
        end
      end

      def find_pattern(file_path, label)
        index = 0

        while index < file_path.length
          unless file_path[index] == '%'
            index += 1
            next
          end
          pattern_start = index
          index += 1
          index += 1 while index < file_path.length && file_path[index].match?(/\d/)
          if index >= file_path.length
            warnings << "#{label} path has an incomplete Slurm filename pattern: #{file_path[pattern_start..]}"
            break
          end

          symbol = file_path[index]
          warnings << "#{label} Paths contains a unrecognised Slurm file pattern: #{file_path[pattern_start..index]}. " unless VALID_FILENAME_PATTERN_SYMBOLS.include?(symbol)
          index += 1
        end
      end

      def validate_time(sbatch_lines)
        time_value = directive_value(sbatch_lines, '--time')
        partition_name = directive_value(sbatch_lines, '--partition')

        max_time_seconds = AlcesJob::Services::SystemLimits.time_limit_seconds(@system_info, partition_name)

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

      # Does not check stuff such as %N yet
      def validate_output(sbatch_lines)
        validate_file_path(sbatch_lines, '--output', 'Output')
      end

      def validate_error(sbatch_lines)
        validate_file_path(sbatch_lines, '--error', 'Error')
      end

      def validate_file_path(sbatch_lines, directive, label)
        file_path = directive_value(sbatch_lines, directive)

        return if file_path.nil?

        if file_path.empty?
          errors << "#{label} path cannot be empty."
          return
        end

        find_pattern(file_path, label)

        directory = File.dirname(file_path)

        return if directory == '.'

        return if Dir.exist?(directory)

        warnings << "#{label} directory does not currently exist: #{directory}."
      end

      def validate_gres(sbatch_lines)
        gres_value = directive_value(sbatch_lines, '--gres')

        return if gres_value.nil?

        if gres_value.empty?
          errors << 'GRES value cannot be empty.'
          return
        end

        gres_parts = gres_value.split(':', -1)
        requested_count = gres_parts.last

        if requested_count.empty?
          errors << "Invalid GRES value: #{gres_value}. Count cannot be empty."
        elsif requested_count.match?(/\A\d+\z/)
          errors << "GRES count must be greater than 0: #{gres_value}." if requested_count.to_i <= 0
        else
          warnings << "No explicit GRES count found in '--gres=#{gres_value}'; assuming 1 resource."
        end
      end

      def unwrap_array_brackets(array_value)
        starts_with_bracket = array_value.start_with?('[')
        ends_with_bracket = array_value.end_with?(']')

        if starts_with_bracket != ends_with_bracket
          errors << "Invalid array value: #{array_value}. Square brackets must wrap the full expression."
          return nil
        end

        expression = starts_with_bracket ? array_value[1..-2] : array_value

        if expression.empty?
          errors << 'Array value cannot be empty.'
          return nil
        end

        expression
      end

      def validate_array(sbatch_lines)
        array_value = directive_value(sbatch_lines, '--array')
        return if array_value.nil?

        if array_value.empty?
          errors << 'Array value cannot be empty.'
          return
        end

        array_expression = unwrap_array_brackets(array_value)
        return if array_expression.nil?

        array_parts = array_expression.split('%', -1)

        if array_parts.length > 2
          errors << "Invalid array value: #{array_value}. Only one concurrency limit is allowed."
          return
        end

        task_expression = array_parts[0]
        concurrency_limit = array_parts[1]

        if task_expression.empty?
          errors << 'Array task indexes cannot be empty.'
          return
        end

        if concurrency_limit
          if concurrency_limit.empty?
            errors << "Invalid array concurrency limit in '#{array_value}'. Expected a positive number after '%'."
            return
          end

          unless concurrency_limit.match?(/\A\d+\z/) && concurrency_limit.to_i.positive?
            errors << "Invalid array concurrency limit '#{concurrency_limit}'. Expected a positive whole number."
            return
          end
        end

        unless task_expression.match?(/\A[\d,\-:]+\z/)
          errors << "Invalid array value: #{array_value}."
          return
        end

        warnings << "Array value '#{array_value}' creates only one task. This is valid, but a normal job may be more appropriate." if task_expression.match?(/\A\d+\z/)

        task_expression.split(',', -1).each do |array_part|
          if array_part.empty?
            errors << "Invalid array value: #{array_value}. Array indexes cannot be empty."
            next
          end

          next unless array_part.include?('-')

          array_range = array_part.match(/\A(\d+)-(\d+)(?::(\d+))?\z/)

          unless array_range
            errors << "Invalid array range: #{array_part}."
            next
          end

          start_value = array_range[1].to_i
          end_value = array_range[2].to_i
          step_value = array_range[3]&.to_i

          errors << "Invalid array range: #{array_part}. Start value must be less than or equal to end value." if start_value > end_value
          errors << "Invalid array step value in #{array_part}. Step must be greater than 0." if step_value&.zero?
        end
      end

      def validate_account(sbatch_lines)
        account_value = directive_value(sbatch_lines, '--account')

        return if account_value.nil?

        return unless account_value.empty?

        errors << 'Account value cannot be empty'
      end

      def validate_mail_type(sbatch_lines)
        mail_type = directive_value(sbatch_lines, '--mail-type')
        return if mail_type.nil?

        if mail_type.empty?
          errors << 'Mail type cannot be empty.'
          return
        end

        mail_types = mail_type.split(',', -1)

        mail_types.each do |individual_mail_type|
          if individual_mail_type.empty?
            errors << 'Mail type values cannot be empty.'
            next
          end

          errors << "Invalid mail type: #{individual_mail_type}." unless VALID_MAIL_TYPES.include?(individual_mail_type)
        end
      end

      def validate_mail_user(sbatch_lines)
        mail_user = directive_value(sbatch_lines, '--mail-user')
        return if mail_user.nil?

        errors << 'Mail user cannot be empty' if mail_user.empty?

        return unless directive_value(sbatch_lines, '--mail-type').nil?

        warnings << 'A --mail-user directive was supplied without --mail-type, so no email events have been selected'
      end

      def validate_mem_per_cpu(sbatch_lines)
      end

      def validate_ntask_per_node(sbatch_lines)
      end

      def validate_mutually_excllusive_directives(sbatch_lines)
        memory_directives = [
          '--mem',
          '--mem-per-cpu',
          '--mem-per-gpu'
        ]

        used_directives = memory_directives.select do |directive|
          !directive_value(sbatch_lines, directive).nil?
        end

        return unless used_directives.length > 1

        errors << "Mutually exclusive directives used together: #{used_directives.join(', ')}."
      end

      def validate_job_name(sbatch_lines)
        job_name = directive_value(sbatch_lines, '--job-name')

        if job_name.nil?
          warnings << 'There is not job name.'
          return
        end
        if job_name.empty?
          errors << 'Job name cannot be empty'
          return
        end

        return if job_name.match?(/\A[a-zA-Z0-9_-]+\z/)

        errors << "Invalid job-name: #{job_name} The program only allows for letters, numbers, hyphens and underscores. "
      end

      def validate_partition(sbatch_lines)
        partition = directive_value(sbatch_lines, '--partition')

        return if partition.nil?

        errors << '--Partition cannot be empty.' if partition.empty?
      end

      def validate_dependency(sbatch_lines)
        dependency_value = directive_value(sbatch_lines, '--dependency')

        return if dependency_value.nil?

        if dependency_value.empty?
          errors << 'Dependency value cannot be empty'
          return
        end
        job_id = dependency_value.split(':', -1).last

        return if job_id.match?(/\A\d+\z/)

        errors << "Invalid dependency value: #{dependency_value}. Expected job ID after ':' "
      end

      def validate_directives_before_commands(lines)
        command_seen = false

        lines.each do |line|
          stripped_line = line.strip

          next if stripped_line.empty?
          next if stripped_line.start_with?('#') && !stripped_line.start_with?('#SBATCH')

          if stripped_line.start_with?('#SBATCH')
            warnings << "#SBATCH directive appears after executable code and will be ignored by slurm: #{stripped_line}" if command_seen
            next
          end
          command_seen = true
        end
      end

      def validate_supported_shebang(lines)
        lines.each do |line|
          next unless line.start_with?('#!')

          shebang_check = line.sub(/\A#!\s*/, '#!').strip

          next if SUPPORTED_SHEBANGS.include?(shebang_check)

          errors << "Unsupported shebang found: #{line}. Supported shebangs are: #{SUPPORTED_SHEBANGS.join(', ')}."
        end
      end

      def validate_sbatch_capital(lines)
        lines.each do |line|
          next unless line.match?(/\A#sbatch\b/i)
          next if line.start_with?('#SBATCH')

          errors << "Invalid SBATCH directive capitalisation: #{line}. Expected '#SBATCH'."
        end
      end

      def validate_duplicate_shebang(lines)
        shebang_lines = lines.select { |line| line.start_with?('#!') }

        return unless shebang_lines.length > 1

        errors << 'Duplicate shebang found. Only one shebang line is allowed.'
      end

      def directive_value(sbatch_lines, directive)
        sbatch_lines.each do |line|
          match = line.match(/\A#SBATCH\s+(\S+?)(?:=|\s+)(.*?)\s*(?:#.*)?\z/)
          next unless match

          found_directive = SbatchDirectiveValidator.convert_alias_to_full_name(match[1])

          return match[2].strip if found_directive == directive
        end

        nil
      end
    end
  end
end
