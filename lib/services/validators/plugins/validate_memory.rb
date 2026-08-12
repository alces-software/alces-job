# frozen_string_literal: true

class SheBangValidator
  attr_reader :errors, :warnings

  def initialize(file_path, system_info:)
    @file_path = file_path
    @errors = []
    @warnings = []
    @system_info = system_info
  end

  def validate?(sbatch_lines:, api:, **)
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
end
