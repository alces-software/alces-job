# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/services/validators/sbatch_directive_validator'

RSpec.describe SbatchDirectiveValidator do
  describe '.validate_directives' do
    it 'does not add errors for valid SBATCH directives' do
      sbatch_lines = [
        '#SBATCH --ntasks=4',
        '#SBATCH --cpus-per-task=8',
        '#SBATCH --nodes=2',
        '#SBATCH --mem=4G',
        '#SBATCH --time=01:00:00',
        '#SBATCH --partition=serial',
        '#SBATCH --job-name=test_job',
        '#SBATCH --output=output.log',
        '#SBATCH --error=error.log'
      ]

      errors = []

      described_class.validate_directives(sbatch_lines, errors)

      expect(errors).to be_empty
    end

    it 'adds an error for an invalid directive' do
      sbatch_lines = [
        '#SBATCH --banana=value'
      ]

      errors = []

      described_class.validate_directives(sbatch_lines, errors)

      expect(errors).to include(
        'Invalid directive found: --banana.'
      )
    end

    it 'adds errors for multiple invalid directives' do
      sbatch_lines = [
        '#SBATCH --banana=value',
        '#SBATCH --wrong=thing'
      ]

      errors = []

      described_class.validate_directives(sbatch_lines, errors)

      expect(errors).to include(
        'Invalid directive found: --banana.',
        'Invalid directive found: --wrong.'
      )
    end

    it 'allows directives without equals values' do
      sbatch_lines = [
        '#SBATCH --ntasks',
        '#SBATCH --mem',
        '#SBATCH --time'
      ]

      errors = []

      described_class.validate_directives(sbatch_lines, errors)

      expect(errors).to be_empty
    end

    it 'detects invalid directives without equals values' do
      sbatch_lines = [
        '#SBATCH --made-up-directive'
      ]

      errors = []

      described_class.validate_directives(sbatch_lines, errors)

      expect(errors).to include(
        'Invalid directive found: --made-up-directive.'
      )
    end

    it 'ignores lines where the directive is missing' do
      sbatch_lines = [
        '#SBATCH'
      ]

      errors = []

      described_class.validate_directives(sbatch_lines, errors)

      expect(errors).to be_empty
    end

    it 'keeps existing errors and appends new ones' do
      sbatch_lines = [
        '#SBATCH --invalid=value'
      ]

      errors = ['Existing error.']

      described_class.validate_directives(sbatch_lines, errors)

      expect(errors).to include('Existing error.')
      expect(errors).to include(
        'Invalid directive found: --invalid.'
      )
    end
  end
end
