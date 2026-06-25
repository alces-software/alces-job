# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'tmpdir'
require_relative '../lib/cli/cli'

RSpec.describe AlcesJob::CLI::Commands::Modify do
  def create_script(content)
    file = Tempfile.new(['job', '.sbatch'])
    file.write(content)
    file.close
    file
  end

  def stub_spinner
    spinner = instance_double(TTY::Spinner)
    allow(spinner).to receive(:update)
    allow(spinner).to receive(:auto_spin)
    allow(spinner).to receive(:success)
    allow(spinner).to receive(:error)
    allow(TTY::Spinner).to receive(:new).and_return(spinner)
  end

  def stub_prompt(save:)
    prompt = instance_double(TTY::Prompt, yes?: save)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
  end

  def stub_validator(valid:, errors: [], warnings: [])
    validator = instance_double(
      AlcesJob::Services::SlurmScriptValidator,
      validate?: valid,
      errors: errors,
      warnings: warnings
    )

    allow(AlcesJob::Services::SlurmScriptValidator).to receive(:new).and_return(validator)
    validator
  end

  def run_modify(script, options = {})
    capture_stdout do
      described_class.new.call(
        script: script,
        **{ module: [], submit: false }.merge(options)
      )
    end
  end

  before do
    stub_spinner
    allow(TTY::Prompt).to receive(:new) { raise 'unexpected prompt' }
    allow(AlcesJob::Services::SlurmScriptValidator).to receive(:new).and_call_original
    allow(AlcesJob::Services).to receive(:module_extractor).and_return([])
  end

  it 'exits with an error when the script path does not exist' do
    missing_path = File.join(Dir.tmpdir, 'missing-job-script.sbatch')

    output = nil
    expect do
      output = run_modify(missing_path)
    end.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }

    expect(output).to include("Script can't be found.")
    expect(TTY::Prompt).not_to have_received(:new)
    expect(AlcesJob::Services::SlurmScriptValidator).not_to have_received(:new)
  end

  it 'does not write changes when the user declines the save prompt' do
    file = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=old
      #SBATCH --time=00:10:00
      #SBATCH --mem=1G

      echo run
    SBATCH
    original_content = File.read(file.path)
    stub_prompt(save: false)

    output = nil
    expect do
      output = run_modify(file.path, job_name: 'new')
    end.to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }

    expect(output).to include('Aborting...')
    expect(File.read(file.path)).to eq(original_content)
    expect(AlcesJob::Services::SlurmScriptValidator).not_to have_received(:new)
  ensure
    file&.unlink
  end

  it 'reverts the script and prints validator errors for invalid option input' do
    file = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=test
      #SBATCH --time=00:10:00
      #SBATCH --mem=1G

      echo run
    SBATCH
    original_content = File.read(file.path)
    stub_prompt(save: true)
    stub_validator(valid: false, errors: ['Invalid memory format: banana.'])

    output = nil
    expect do
      output = run_modify(file.path, mem: 'banana')
    end.to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }

    expect(output).to include('Changes were invalid, so the script was reverted.')
    expect(output).to include('ERROR:')
    expect(output).to include('Invalid memory format: banana.')
    expect(File.read(file.path)).to eq(original_content)
  ensure
    file&.unlink
  end

  it 'exits with an error when the output file path cannot be written' do
    file = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=test
      #SBATCH --time=00:10:00
      #SBATCH --mem=1G

      echo run
    SBATCH
    stub_prompt(save: true)
    missing_dir_output = File.join(Dir.tmpdir, 'alces-job-missing-dir', 'job.sbatch')

    output = nil
    expect do
      output = run_modify(file.path, output_file: missing_dir_output)
    end.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }

    expect(output).to include('An error occurred while writing to the file:')
    expect(AlcesJob::Services::SlurmScriptValidator).not_to have_received(:new)
  ensure
    file&.unlink
  end
end
