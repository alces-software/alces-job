# frozen_string_literal: true

module AlcesJob
  module Services
    module SbatchDirectiveValidator
      VALID_DIRECTIVES = [ # capitalised so it is a constant
        '--ntasks',
        '--cpus-per-task',
        '--nodes',
        '--mem',
        '--time',
        '--partition',
        '--job-name',
        '--output',
        '--error',
        '--gres',
        '--array',
        '--dependency',
        '--account',
        '--mail-type',
        '--mail-user'

      ].freeze # immutable array of valid directives for now

      def self.validate_directives(sbatch_lines, errors)
        sbatch_lines.each do |line|
          directive = line.split[1]&.split('=')&.first
          next if directive.nil?

          errors << "Invalid directive found: #{directive}." unless VALID_DIRECTIVES.include?(directive)
        end
      end
    end
  end
end
