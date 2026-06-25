# frozen_string_literal: true

require_relative 'sbatch_directive_validator'

module AlcesJob
  module Services
    module IntegerDirectiveValidator
      INTEGER_DIRECTIVES = [
        '--ntasks',
        '--cpus-per-task',
        '--nodes'
      ].freeze

      def self.validate(sbatch_lines, errors)
        sbatch_lines.each do |line|
          match = line.match(/\A#SBATCH\s+(\S+?)(?:=|\s+)(.*?)\s*(?:#.*)?\z/)
          next unless match

          raw_directive = match[1]
          value = match[2].strip

          directive = SbatchDirectiveValidator.convert_alias_to_full_name(raw_directive)

          next unless INTEGER_DIRECTIVES.include?(directive)

          errors << "Invalid format for #{directive}: #{value}. Expected a positive integer value." unless value.match?(/\A[1-9]\d*\z/)
        end
      end
    end
  end
end
