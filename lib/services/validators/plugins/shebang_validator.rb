# frozen_string_literal: true

class SheBangValidator
  attr_reader :errors, :warnings

  def initialize(file_path, system_info:)
    @file_path = file_path
    @errors = []
    @warnings = []
    @system_info = system_info
  end

  def validate?(sbatch_lines:, **)
    return unless sbatch_lines.empty?

    errors << 'No #SBATCH directives found.'
  end
end
