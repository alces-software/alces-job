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
    directive_names = sbatch_lines.filter_map do |line|
      raw_directive = line.split[1]&.split('=')&.first
      next if raw_directive.nil?

      api.convert_directive_alias_to_full_name(raw_directive)
    end

    directive_names.tally.each do |directive, count|
      next unless count > 1

      errors << "Duplicate directive found: #{directive}."
    end
  end
end
