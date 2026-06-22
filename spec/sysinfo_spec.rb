# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/services/sysinfo'

RSpec.describe AlcesJob::Services::SysInfo do
  let(:success_status) { instance_double(Process::Status, success?: true) }
  let(:failure_status) { instance_double(Process::Status, success?: false) }

  describe '.node_info' do
    it 'returns node information from sinfo output' do
      stdout = <<~OUTPUT
        node01 64 385024
        node02 32 192000
      OUTPUT

      allow(Open3).to receive(:capture3)
        .with('sinfo -N -h -o "%N %c %m"')
        .and_return([stdout, '', success_status])

      expect(described_class.node_info).to eq(
        [
          { node: 'node01', cpus: 64, memory: 385_024 },
          { node: 'node02', cpus: 32, memory: 192_000 }
        ]
      )
    end

    it 'returns nil when the command fails' do
      allow(Open3).to receive(:capture3)
        .with('sinfo -N -h -o "%N %c %m"')
        .and_return(['', 'error', failure_status])

      expect(described_class.node_info).to be_nil
    end

    it 'returns nil when sinfo is not installed' do
      allow(Open3).to receive(:capture3)
        .with('sinfo -N -h -o "%N %c %m"')
        .and_raise(Errno::ENOENT)

      expect(described_class.node_info).to be_nil
    end
  end

  describe '.partition_info' do
    it 'returns partition information from sinfo output' do
      stdout = <<~OUTPUT
        serial* 7-00:00:00
        gpu-h100 03:00:00
      OUTPUT

      allow(Open3).to receive(:capture3)
        .with('sinfo -o "%P %l" -h')
        .and_return([stdout, '', success_status])

      expect(described_class.partition_info).to eq(
        [
          { partition: 'serial', time_limit: '7-00:00:00', default: true },
          { partition: 'gpu-h100', time_limit: '0-03:00:00', default: false }
        ]
      )
    end

    it 'converts infinite time limits to 00:00:00' do
      stdout = <<~OUTPUT
        long infinite
      OUTPUT

      allow(Open3).to receive(:capture3)
        .with('sinfo -o "%P %l" -h')
        .and_return([stdout, '', success_status])

      expect(described_class.partition_info).to eq(
        [
          { partition: 'long', time_limit: '0-00:00:00', default: false }
        ]
      )
    end

    it 'returns nil when the command fails' do
      allow(Open3).to receive(:capture3)
        .with('sinfo -o "%P %l" -h')
        .and_return(['', 'error', failure_status])

      expect(described_class.partition_info).to be_nil
    end

    it 'returns nil when sinfo is not installed' do
      allow(Open3).to receive(:capture3)
        .with('sinfo -o "%P %l" -h')
        .and_raise(Errno::ENOENT)

      expect(described_class.partition_info).to be_nil
    end
  end

  describe '.package_info' do
    it 'returns package names from module avail output' do
      stdout = <<~OUTPUT
        /apps/modules:
        miniconda/24.9.2
        gcc/12.2.0
      OUTPUT

      allow(Open3).to receive(:capture3)
        .with('module avail')
        .and_return([stdout, '', success_status])

      expect(described_class.package_info).to eq(
        [
          '',
          'miniconda',
          'gcc'
        ]
      )
    end

    it 'returns nil when the command fails' do
      allow(Open3).to receive(:capture3)
        .with('module avail')
        .and_return(['', 'error', failure_status])

      expect(described_class.package_info).to be_nil
    end

    it 'returns nil when module command is not installed' do
      allow(Open3).to receive(:capture3)
        .with('module avail')
        .and_raise(Errno::ENOENT)

      expect(described_class.package_info).to be_nil
    end
  end

  describe '.gpu_info' do
    it 'returns the GPU count from command output' do
      allow(Open3).to receive(:capture3)
        .with("scontrol show nodes | grep -o 'gpu:[^:]*:[0-9]*' | cut -d':' -f3 | paste -sd+ | bc")
        .and_return(["4\n", '', success_status])

      expect(described_class.gpu_info).to eq(4)
    end

    it 'returns zero when the command fails' do
      allow(Open3).to receive(:capture3)
        .with("scontrol show nodes | grep -o 'gpu:[^:]*:[0-9]*' | cut -d':' -f3 | paste -sd+ | bc")
        .and_return(['', 'error', failure_status])

      expect(described_class.gpu_info).to eq(0)
    end

    it 'returns zero when scontrol is not installed' do
      allow(Open3).to receive(:capture3)
        .with("scontrol show nodes | grep -o 'gpu:[^:]*:[0-9]*' | cut -d':' -f3 | paste -sd+ | bc")
        .and_raise(Errno::ENOENT)

      expect(described_class.gpu_info).to eq(0)
    end
  end

  describe '.all_info' do
    it 'returns all system information in one hash' do
      allow(described_class).to receive_messages(node_info: [{ node: 'node01', cpus: 64, memory: 385_024 }], partition_info: [{ partition: 'serial', time_limit: '7-00:00:00', default: true }], package_info: %w[miniconda gcc], gpu_info: 4)

      expect(described_class.all_info).to eq(
        {
          nodes: [{ node: 'node01', cpus: 64, memory: 385_024 }],
          partitions: [{ partition: 'serial', time_limit: '7-00:00:00', default: true }],
          packages: %w[miniconda gcc],
          gpu_total: 4
        }
      )
    end

    it 'fills missing values with defaults when slurm is unavailable' do
      allow(described_class).to receive_messages(node_info: nil, partition_info: nil, package_info: nil, gpu_info: 0)

      expect(described_class.all_info).to eq(
        {
          nodes: [{ node: 'local', cpus: 4, memory: 5_000 }],
          partitions: [{ partition: 'default', time_limit: '0-07:00:00', default: true }],
          packages: [],
          gpu_total: 0
        }
      )
    end
  end

  describe '.slurm_available?' do
    it 'returns true when node and partition info exist' do
      info = {
        nodes: [{ node: 'node01', cpus: 4, memory: 8_000 }],
        partitions: [{ partition: 'default', time_limit: '0-07:00:00', default: true }]
      }

      expect(described_class.slurm_available?(info)).to be true
    end

    it 'returns false when node or partition info is missing' do
      info = {
        nodes: nil,
        partitions: nil
      }

      expect(described_class.slurm_available?(info)).to be false
    end
  end
end
