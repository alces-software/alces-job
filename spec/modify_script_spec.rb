# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'tmpdir'
require_relative '../lib/services/modify_script'

RSpec.describe AlcesJob::Services::ModifyScript do
  def create_script(content)
    file = Tempfile.new(['job', '.sbatch'])
    file.write(content)
    file.close
    file
  end

  def approve_prompt
    prompt = instance_double(TTY::Prompt, yes?: true)
    allow(TTY::Prompt).to receive(:new).and_return(prompt)
  end

  def stub_validator(valid: true, errors: [], warnings: [])
    validator = instance_double(
      SlurmScriptValidator,
      validate?: valid,
      errors: errors,
      warnings: warnings
    )

    allow(SlurmScriptValidator).to receive(:new).and_return(validator)
    validator
  end

  def modify(script_path, options = {}, **option_keywords)
    valid = option_keywords.delete(:valid) { true }
    errors = option_keywords.delete(:errors) { [] }
    warnings = option_keywords.delete(:warnings) { [] }

    approve_prompt
    stub_validator(valid: valid, errors: errors, warnings: warnings)
    options = options.merge(option_keywords)

    capture_stdout do
      described_class.new(
        script: script_path,
        options: { module: [], submit: false }.merge(options)
      ).call
    end
  end

  it 'updates equals, space, and compact short sbatch directives without duplicating them' do
    file = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=old
      #SBATCH --time 00:30:00
      #SBATCH -N2
      #SBATCH -o=old.out
      #SBATCH --mem=2G

      export FOO=bar
      echo run
    SBATCH

    modify(
      file.path,
      job_name: 'new',
      time: '01:00:00',
      nodes: 4,
      output: 'new.out',
      mem: '4G'
    )

    content = File.read(file.path)

    expect(content).to include('#SBATCH --job-name=new')
    expect(content).to include('#SBATCH --time=01:00:00')
    expect(content).to include('#SBATCH --nodes=4')
    expect(content).to include('#SBATCH --output=new.out')
    expect(content).to include('#SBATCH --mem=4G')
    expect(content).to include('export FOO=bar')
    expect(content).to include('echo run')
    expect(content).not_to include('#SBATCH --time 00:30:00')
    expect(content).not_to include('#SBATCH -N2')
    expect(content).not_to include('#SBATCH -o=old.out')
    expect(content).not_to include('echo "Running job')
  ensure
    file&.unlink
  end

  it 'inserts missing sbatch directives after the existing directive block' do
    file = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=test
      #SBATCH --time=00:10:00
      #SBATCH --mem=1G

      echo run
    SBATCH

    modify(file.path, partition: 'short', cpus_per_task: 2)

    lines = File.readlines(file.path, chomp: true)

    expect(lines).to eq(
      [
        '#!/bin/bash',
        '#SBATCH --job-name=test',
        '#SBATCH --time=00:10:00',
        '#SBATCH --mem=1G',
        '#SBATCH --partition=short',
        '#SBATCH --cpus-per-task=2',
        '',
        'echo run'
      ]
    )
  ensure
    file&.unlink
  end

  it 'inserts new modules and workdir before the body in a stable order' do
    file = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=test
      #SBATCH --time=00:10:00
      #SBATCH --mem=1G

      echo run
    SBATCH

    modify(file.path, module: %w[ruby ruby python], workdir: '/work dir')

    lines = File.readlines(file.path, chomp: true)

    expect(lines).to eq(
      [
        '#!/bin/bash',
        '#SBATCH --job-name=test',
        '#SBATCH --time=00:10:00',
        '#SBATCH --mem=1G',
        'module load ruby',
        'module load python',
        'cd /work\ dir',
        '',
        'echo run'
      ]
    )
  ensure
    file&.unlink
  end

  it 'replaces top-level module and cd lines without touching indented function setup' do
    file = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=test
      #SBATCH --time=00:10:00
      #SBATCH --mem=1G

      setup() {
        module load hidden
        cd /inside
      }
      module load old
      cd /old
      echo run
    SBATCH

    modify(file.path, module: %w[ruby python], workdir: '/work')

    content = File.read(file.path)

    expect(content).to include('  module load hidden')
    expect(content).to include('  cd /inside')
    expect(content).to include('module load ruby')
    expect(content).to include('module load python')
    expect(content).to include('cd /work')
    expect(content).not_to include('module load old')
    expect(content).not_to include('cd /old')
  ensure
    file&.unlink
  end

  it 'replaces the generated placeholder command' do
    file = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=test
      #SBATCH --time=00:10:00
      #SBATCH --mem=1G

      echo 'No command provided'
    SBATCH

    modify(file.path, command: 'python run.py')

    content = File.read(file.path)

    expect(content).to include('python run.py')
    expect(content).not_to include("echo 'No command provided'")
  ensure
    file&.unlink
  end

  it 'appends a command without deleting existing setup when there is no placeholder' do
    file = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=test
      #SBATCH --time=00:10:00
      #SBATCH --mem=1G

      export FOO=bar
      python old.py
    SBATCH

    modify(file.path, command: 'python new.py')

    content = File.read(file.path)

    expect(content).to include('export FOO=bar')
    expect(content).to include('python old.py')
    expect(content).to end_with("python new.py\n")
  ensure
    file&.unlink
  end

  it 'updates an existing running echo but does not add one to scripts without it' do
    file = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=old
      #SBATCH --time=00:10:00
      #SBATCH --mem=1G

      echo "Running job: 'old'"
      python run.py
    SBATCH

    modify(file.path, job_name: 'new')

    content = File.read(file.path)

    expect(content).to include(%(echo "Running job: 'new'"))
    expect(content).not_to include(%(echo "Running job: 'old'"))
  ensure
    file&.unlink
  end

  it 'restores an existing output file when validation fails' do
    input = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=test
      #SBATCH --time=00:10:00
      #SBATCH --mem=1G

      echo run
    SBATCH

    Dir.mktmpdir do |dir|
      output_path = File.join(dir, 'output.sbatch')
      File.write(output_path, "previous output\n")

      modify(
        input.path,
        { output_file: output_path, mem: 'invalid' },
        valid: false,
        errors: ['Invalid memory format']
      )

      expect(File.read(output_path)).to eq("previous output\n")
      expect(File.read(input.path)).to include('#SBATCH --mem=1G')
    end
  ensure
    input&.unlink
  end

  it 'removes a newly created output file when validation fails' do
    input = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=test
      #SBATCH --time=00:10:00
      #SBATCH --mem=1G

      echo run
    SBATCH

    Dir.mktmpdir do |dir|
      output_path = File.join(dir, 'output.sbatch')

      modify(
        input.path,
        { output_file: output_path, mem: 'invalid' },
        valid: false,
        errors: ['Invalid memory format']
      )

      expect(File).not_to exist(output_path)
      expect(File.read(input.path)).to include('#SBATCH --mem=1G')
    end
  ensure
    input&.unlink
  end

  it 'submits without invoking a shell' do
    file = create_script(<<~SBATCH)
      #!/bin/bash
      #SBATCH --job-name=test
      #SBATCH --time=00:10:00
      #SBATCH --mem=1G

      echo run
    SBATCH
    status = instance_double(Process::Status, exitstatus: 0)

    expect(Open3).to receive(:capture3)
      .with('sbatch', file.path)
      .and_return(['Submitted batch job 1', '', status])

    modify(file.path, submit: true, mem: '2G')
  ensure
    file&.unlink
  end
end
