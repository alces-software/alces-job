# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/services/validators/integer_directive_validator'

RSpec.describe IntegerDirectiveValidator do
  describe '.validate' do
    it 'does not add errors for valid positive integer directives' do
      sbatch_lines = [
        '#SBATCH --ntasks=4',
        '#SBATCH --cpus-per-task=8',
        '#SBATCH --nodes=2'
      ]

      errors = []

      described_class.validate(sbatch_lines, errors)

      expect(errors).to be_empty
    end

    it 'adds an error when --ntasks is zero' do
      sbatch_lines = [
        '#SBATCH --ntasks=0'
      ]

      errors = []

      described_class.validate(sbatch_lines, errors)

      expect(errors).to include(
        'Invalid format for --ntasks: 0. Expected a positive integer value.'
      )
    end

    it 'adds an error when --cpus-per-task is zero' do
      sbatch_lines = [
        '#SBATCH --cpus-per-task=0'
      ]

      errors = []

      described_class.validate(sbatch_lines, errors)

      expect(errors).to include(
        'Invalid format for --cpus-per-task: 0. Expected a positive integer value.'
      )
    end

    it 'adds an error when --nodes is zero' do
      sbatch_lines = [
        '#SBATCH --nodes=0'
      ]

      errors = []

      described_class.validate(sbatch_lines, errors)

      expect(errors).to include(
        'Invalid format for --nodes: 0. Expected a positive integer value.'
      )
    end

    it 'adds an error when the value is negative' do
      sbatch_lines = [
        '#SBATCH --ntasks=-2'
      ]

      errors = []

      described_class.validate(sbatch_lines, errors)

      expect(errors).to include(
        'Invalid format for --ntasks: -2. Expected a positive integer value.'
      )
    end

    it 'adds an error when the value is a decimal' do
      sbatch_lines = [
        '#SBATCH --cpus-per-task=2.5'
      ]

      errors = []

      described_class.validate(sbatch_lines, errors)

      expect(errors).to include(
        'Invalid format for --cpus-per-task: 2.5. Expected a positive integer value.'
      )
    end

    it 'adds an error when the value is text' do
      sbatch_lines = [
        '#SBATCH --nodes=two'
      ]

      errors = []

      described_class.validate(sbatch_lines, errors)

      expect(errors).to include(
        'Invalid format for --nodes: two. Expected a positive integer value.'
      )
    end

    it 'does nothing when no integer directives are present' do
      sbatch_lines = [
        '#SBATCH --job-name=test',
        '#SBATCH --time=01:00:00',
        '#SBATCH --mem=4G'
      ]

      errors = []

      described_class.validate(sbatch_lines, errors)

      expect(errors).to be_empty
    end

    it 'keeps existing errors and appends new ones' do
      sbatch_lines = [
        '#SBATCH --nodes=abc'
      ]

      errors = ['Existing error.']

      described_class.validate(sbatch_lines, errors)

      expect(errors).to include('Existing error.')
      expect(errors).to include(
        'Invalid format for --nodes: abc. Expected a positive integer value.'
      )
    end
  end
end
