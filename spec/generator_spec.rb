# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe AlcesJob::Services::Generator do
  let(:pwd) { Dir.pwd }

  after do
    # cleanup only generated outputs
    FileUtils.rm_f(File.join(pwd, 'job.sbatch'))
    FileUtils.rm_f(File.join(pwd, 'custom.sbatch'))
    FileUtils.rm_f(File.join(pwd, 'integration.sbatch'))
  end

  describe '#generate' do
    it 'renders default template when none is provided' do
      generator = described_class.new(job_name: 'test_job')

      script = generator.generate

      expect(script).to include('test_job')
    end

    it 'uses gpu template when specified' do
      generator = described_class.new(
        job_name: 'gpu_job',
        template: 'gpu',
        gres: 'gpu:2'
      )

      script = generator.generate

      expect(script).to include('gpu_job')
      expect(script).to include('gpu:2')
    end

    it 'uses mpi template when specified' do
      generator = described_class.new(
        nodes: 2,
        command: 'run_mpi',
        template: 'mpi'
      )

      script = generator.generate

      expect(script).to include('run_mpi')
    end

    it 'uses array template when specified' do
      generator = described_class.new(
        array: '0-10',
        template: 'array'
      )

      script = generator.generate

      expect(script).to include('0-10')
    end
  end

  describe '#save' do
    it 'writes to job.sbatch by default' do
      generator = described_class.new(job_name: 'save_test')

      generator.save(generator.generate)

      path = File.join(Dir.pwd, 'job.sbatch')

      expect(File).to exist(path)
      expect(File.read(path)).to include('save_test')
    end

    it 'writes to output_file when provided' do
      generator = described_class.new(
        job_name: 'save_test',
        output_file: 'custom.sbatch'
      )

      generator.save(generator.generate)

      path = File.join(Dir.pwd, 'custom.sbatch')

      expect(File).to exist(path)
      expect(File.read(path)).to include('save_test')
    end
  end

  describe 'end-to-end' do
    it 'generates and saves a valid sbatch script' do
      generator = described_class.new(
        job_name: 'integration_test',
        template: 'gpu',
        gres: 'gpu:1',
        output_file: 'integration.sbatch'
      )

      script = generator.generate
      generator.save(script)

      path = File.join(Dir.pwd, 'integration.sbatch')

      expect(File).to exist(path)
      expect(File.read(path)).to include('integration_test')
    end
  end
end
