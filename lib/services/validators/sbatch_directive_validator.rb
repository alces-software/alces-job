# frozen_string_literal: true

module AlcesJob
  module Services
    module SbatchDirectiveValidator
      VALID_DIRECTIVES = [ # capitalised so it is a constant
        '--ntasks',
        '--cpus-per-task',
        '--nodes',
        '--mem',
        '--mem-per-cpu',
        '--ntasks-per-node',
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

      DIRECTIVE_ALIASES = {
        '-t' => '--time',
        '-n' => '--ntasks',
        '-N' => '--nodes',
        '-p' => '--partition',
        '-J' => '--job-name',
        '-o' => '--output',
        '-e' => '--error',
        '-a' => '--array',
        '-A' => '--account'
      }.freeze

      def self.convert_alias_to_full_name(directive)
        DIRECTIVE_ALIASES.fetch(directive, directive)
      end

      def self.validate_directives(sbatch_lines, errors)
        sbatch_lines.each do |line|
          raw_directive = line.split[1]&.split('=')&.first
          next if raw_directive.nil?

          directive = convert_alias_to_full_name(raw_directive)

          errors << "Invalid directive found: #{raw_directive}." unless VALID_DIRECTIVES.include?(directive)
        end
      end
    end
  end
end
