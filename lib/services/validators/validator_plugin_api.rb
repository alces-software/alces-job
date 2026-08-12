# frozen_string_literal: true

module AlcesJon
  module Services
    module Plugins
      class ValidatorPluginAPI
        class << self
          VALID_DIRECTIVES = [
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
          ].freeze

          DIRECTIVE_ALIASES = {
            '-t' => '--time',
            '-n' => '--ntasks',
            '-N' => '--nodes',
            '-p' => '--partition',
            '-J' => '--job-name',
            '-o' => '--output',
            '-e' => '--error',
            '-a' => '--array',
            '-A' => '--account',
            '-c' => '--cpus-per-task'
          }.freeze

          INTEGER_DIRECTIVES = [
            '--ntasks',
            '--cpus-per-task',
            '--nodes'
          ].freeze

          def convert_directive_alias_to_full_name(directive)
            DIRECTIVE_ALIASES.fetch(directive, directive)
          end

          def validate_string_directives(sbatch_lines, errors)
            sbatch_lines.each do |line|
              raw_directive = line.split[1]&.split('=')&.first
              next if raw_directive.nil?

              directive = convert_alias_to_full_name(raw_directive)

              errors << "Invalid directive found: #{raw_directive}." unless VALID_DIRECTIVES.include?(directive)
            end
          end

          def validate_integer_directives(sbatch_lines, errors)
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
  end
end
