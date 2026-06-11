# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require_relative '../lib/services/slurm_script_validator'

RSpec.describe SlurmScriptValidator do
  def create_script(content)
    file = Tempfile.new(['job', '.sbatch'])
    file.write(content)
    file.close
    file
  end

  def validate_script(content, system_info: nil)
    file = create_script(content)

    validator = described_class.new(file.path, system_info: system_info)
    result = validator.validate

    [result, validator.errors, validator.warnings]
  ensure
    file&.unlink
  end

  let(:system_info) do
    {
      nodes: [
        { memory: 32_000, cpus: 32 }
      ],
      partitions: [
        { partition: 'short', time_limit: '1-00:00:00' }
      ]
    }
  end

  describe '#validate' do
    it 'returns true for a valid sbatch script' do
      result, errors, warnings = validate_script(
        <<~SBATCH,
          #!/bin/bash
          #SBATCH --job-name=test_job
          #SBATCH --partition=short
          #SBATCH --time=01:00:00
          #SBATCH --mem=4G
          #SBATCH --cpus-per-task=2

          echo "Hello"
        SBATCH
        system_info: system_info
      )

      expect(result).to be true
      expect(errors).to be_empty
      expect(warnings).to be_empty
    end

    it 'returns false when the shebang is missing' do
      result, errors, = validate_script(
        <<~SBATCH,
          #SBATCH --job-name=test_job
          #SBATCH --time=01:00:00
          #SBATCH --mem=4G

          echo "Hello"
        SBATCH
        system_info: system_info
      )

      expect(result).to be false
      expect(errors).to include(
        'Missing shebang, spelt incorrectly, or unsupported. Expected: #!/bin/bash.'
      )
    end

    it 'returns false when the shebang is incorrect' do
      result, errors, = validate_script(
        <<~SBATCH,
          #!/usr/bin/env bash
          #SBATCH --job-name=test_job
          #SBATCH --time=01:00:00
          #SBATCH --mem=4G

          echo "Hello"
        SBATCH
        system_info: system_info
      )

      expect(result).to be false
      expect(errors).to include(
        'Missing shebang, spelt incorrectly, or unsupported. Expected: #!/bin/bash.'
      )
    end

    it 'returns false when no SBATCH directives are present' do
      result, errors, = validate_script(
        <<~SBATCH,
          #!/bin/bash

          echo "Hello"
        SBATCH
        system_info: system_info
      )

      expect(result).to be false
      expect(errors).to include('No #SBATCH directives found.')
    end

    it 'returns false when duplicate directives are present' do
      result, errors, = validate_script(
        <<~SBATCH,
          #!/bin/bash
          #SBATCH --job-name=test_job
          #SBATCH --job-name=other_job
          #SBATCH --time=01:00:00
          #SBATCH --mem=4G

          echo "Hello"
        SBATCH
        system_info: system_info
      )

      expect(result).to be false
      expect(errors).to include('Duplicate directive found: --job-name.')
    end

    it 'warns when no memory directive is present' do
      result, errors, warnings = validate_script(
        <<~SBATCH,
          #!/bin/bash
          #SBATCH --job-name=test_job
          #SBATCH --time=01:00:00

          echo "Hello"
        SBATCH
        system_info: system_info
      )

      expect(result).to be true
      expect(errors).to be_empty
      expect(warnings).to include('No --mem directive found.')
    end

    it 'warns when no time directive is present' do
      result, errors, warnings = validate_script(
        <<~SBATCH,
          #!/bin/bash
          #SBATCH --job-name=test_job
          #SBATCH --mem=4G

          echo "Hello"
        SBATCH
        system_info: system_info
      )

      expect(result).to be true
      expect(errors).to be_empty
      expect(warnings).to include('No --time directive found.')
    end

    it 'returns false when memory format is invalid' do
      result, errors, = validate_script(
        <<~SBATCH,
          #!/bin/bash
          #SBATCH --job-name=test_job
          #SBATCH --time=01:00:00
          #SBATCH --mem=banana

          echo "Hello"
        SBATCH
        system_info: system_info
      )

      expect(result).to be false
      expect(errors).to include(
        'Invalid memory format: banana. Expected formats like 4G, 500M, etc.'
      )
    end

    it 'returns false when requested memory exceeds the system limit' do
      result, errors, = validate_script(
        <<~SBATCH,
          #!/bin/bash
          #SBATCH --job-name=test_job
          #SBATCH --time=01:00:00
          #SBATCH --mem=64G

          echo "Hello"
        SBATCH
        system_info: system_info
      )

      expect(result).to be false
      expect(errors).to include(
        'Requested memory (65536 MB) exceeds the maximum allowed (32000 MB).'
      )
    end

    it 'returns false when time format is invalid' do
      result, errors, = validate_script(
        <<~SBATCH,
          #!/bin/bash
          #SBATCH --job-name=test_job
          #SBATCH --time=banana
          #SBATCH --mem=4G

          echo "Hello"
        SBATCH
        system_info: system_info
      )

      expect(result).to be false
      expect(errors).to include(
        'Invalid time format. Expected HH:MM:SS or D-HH:MM:SS.'
      )
    end

    it 'returns false when requested time exceeds the system limit' do
      result, errors, = validate_script(
        <<~SBATCH,
          #!/bin/bash
          #SBATCH --job-name=test_job
          #SBATCH --time=2-00:00:00
          #SBATCH --mem=4G

          echo "Hello"
        SBATCH
        system_info: system_info
      )

      expect(result).to be false
      expect(errors).to include(
        'Requested time (172800 seconds) exceeds the maximum allowed (86400 seconds).'
      )
    end
  end
end
