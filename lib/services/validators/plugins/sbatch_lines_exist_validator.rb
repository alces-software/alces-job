# frozen_string_literal: true

class SheBangValidator
  attr_reader :errors, :warnings

  def initialize(file_path, system_info:)
    @file_path = file_path
    @errors = []
    @warnings = []
    @system_info = system_info
  end

  def validate?(lines:, api:, **)
    if lines.empty?
      errors << 'Script is empty.'
      return
    end

    shebang_check = lines[0].sub(/\A#!\s*/, '#!').strip
    return if SUPPORTED_SHEBANGS.include?(shebang_check)

    errors << "Missing shebang, spelt incorrectly, or unsupported. Expected one of: #{SUPPORTED_SHEBANGS.join(',')}."
  end
end
