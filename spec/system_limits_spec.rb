# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/services/sys_limits/system_limits'

RSpec.describe AlcesJob::Services::SystemLimits do
  describe '.nodes_from' do
    it 'returns an empty array when system_info is nil' do
      expect(described_class.nodes_from(nil)).to eq([])
    end

    it 'returns nodes using symbol keys' do
      system_info = {
        nodes: [
          { node: 'node01', memory: 32_000, cpus: 32 }
        ]
      }

      expect(described_class.nodes_from(system_info)).to eq(
        [
          { node: 'node01', memory: 32_000, cpus: 32 }
        ]
      )
    end

    it 'returns nodes using string keys' do
      system_info = {
        'nodes' => [
          { 'node' => 'node01', 'memory' => 32_000, 'cpus' => 32 }
        ]
      }

      expect(described_class.nodes_from(system_info)).to eq(
        [
          { 'node' => 'node01', 'memory' => 32_000, 'cpus' => 32 }
        ]
      )
    end
  end

  describe '.partitions_from' do
    it 'returns an empty array when system_info is nil' do
      expect(described_class.partitions_from(nil)).to eq([])
    end

    it 'returns partitions using symbol keys' do
      system_info = {
        partitions: [
          { partition: 'short', time_limit: '1-00:00:00' }
        ]
      }

      expect(described_class.partitions_from(system_info)).to eq(
        [
          { partition: 'short', time_limit: '1-00:00:00' }
        ]
      )
    end

    it 'returns partitions using string keys' do
      system_info = {
        'partitions' => [
          { 'partition' => 'short', 'time_limit' => '1-00:00:00' }
        ]
      }

      expect(described_class.partitions_from(system_info)).to eq(
        [
          { 'partition' => 'short', 'time_limit' => '1-00:00:00' }
        ]
      )
    end
  end

  describe '.node_count' do
    it 'returns the default node count when system_info is nil' do
      expect(described_class.node_count(nil)).to eq(1)
    end

    it 'returns the number of nodes' do
      system_info = {
        nodes: [
          { node: 'node01' },
          { node: 'node02' }
        ]
      }

      expect(described_class.node_count(system_info)).to eq(2)
    end
  end

  describe '.max_memory_mb' do
    it 'returns the default memory when system_info is nil' do
      expect(described_class.max_memory_mb(nil)).to eq(5_000)
    end

    it 'returns the maximum memory using symbol keys' do
      system_info = {
        nodes: [
          { memory: 32_000 },
          { memory: 64_000 }
        ]
      }

      expect(described_class.max_memory_mb(system_info)).to eq(64_000)
    end

    it 'returns the maximum memory using string keys' do
      system_info = {
        'nodes' => [
          { 'memory' => 32_000 },
          { 'memory' => 64_000 }
        ]
      }

      expect(described_class.max_memory_mb(system_info)).to eq(64_000)
    end

    it 'returns the default memory when memory values are missing' do
      system_info = {
        nodes: [
          { node: 'node01' },
          { node: 'node02' }
        ]
      }

      expect(described_class.max_memory_mb(system_info)).to eq(5_000)
    end
  end

  describe '.max_cpus_per_node' do
    it 'returns the default CPU count when system_info is nil' do
      expect(described_class.max_cpus_per_node(nil)).to eq(4)
    end

    it 'returns the maximum CPU count using symbol keys' do
      system_info = {
        nodes: [
          { cpus: 16 },
          { cpus: 64 }
        ]
      }

      expect(described_class.max_cpus_per_node(system_info)).to eq(64)
    end

    it 'returns the maximum CPU count using string keys' do
      system_info = {
        'nodes' => [
          { 'cpus' => 16 },
          { 'cpus' => 64 }
        ]
      }

      expect(described_class.max_cpus_per_node(system_info)).to eq(64)
    end

    it 'returns the default CPU count when CPU values are missing' do
      system_info = {
        nodes: [
          { node: 'node01' }
        ]
      }

      expect(described_class.max_cpus_per_node(system_info)).to eq(4)
    end
  end

  describe '.valid_partitions' do
    it 'returns an empty array when system_info is nil' do
      expect(described_class.valid_partitions(nil)).to eq([])
    end

    it 'returns partition names using symbol keys' do
      system_info = {
        partitions: [
          { partition: 'short' },
          { partition: 'gpu-h100' }
        ]
      }

      expect(described_class.valid_partitions(system_info)).to eq(
        %w[short gpu-h100]
      )
    end

    it 'returns partition names using string keys' do
      system_info = {
        'partitions' => [
          { 'partition' => 'short' },
          { 'partition' => 'gpu-h100' }
        ]
      }

      expect(described_class.valid_partitions(system_info)).to eq(
        %w[short gpu-h100]
      )
    end
  end

  describe '.find_partition' do
    let(:partitions) do
      [
        { partition: 'short', time_limit: '1-00:00:00' },
        { partition: 'gpu-h100', time_limit: '0-03:00:00' }
      ]
    end

    it 'returns the first partition when no partition name is given' do
      expect(described_class.find_partition(partitions, nil)).to eq(
        { partition: 'short', time_limit: '1-00:00:00' }
      )
    end

    it 'finds a partition by name' do
      expect(described_class.find_partition(partitions, 'gpu-h100')).to eq(
        { partition: 'gpu-h100', time_limit: '0-03:00:00' }
      )
    end

    it 'returns the first partition when the named partition is not found' do
      expect(described_class.find_partition(partitions, 'missing')).to eq(
        { partition: 'short', time_limit: '1-00:00:00' }
      )
    end
  end

  describe '.time_limit_seconds' do
    it 'returns the default time limit when system_info is nil' do
      expect(described_class.time_limit_seconds(nil)).to eq(86_400)
    end

    it 'returns the first partition time limit when no partition is given' do
      system_info = {
        partitions: [
          { partition: 'short', time_limit: '1-00:00:00' }
        ]
      }

      expect(described_class.time_limit_seconds(system_info)).to eq(86_400)
    end

    it 'returns the named partition time limit' do
      system_info = {
        partitions: [
          { partition: 'short', time_limit: '1-00:00:00' },
          { partition: 'gpu-h100', time_limit: '0-03:00:00' }
        ]
      }

      expect(described_class.time_limit_seconds(system_info, 'gpu-h100')).to eq(10_800)
    end

    it 'uses the default time limit when the time format is invalid' do
      system_info = {
        partitions: [
          { partition: 'broken', time_limit: 'banana' }
        ]
      }

      expect(described_class.time_limit_seconds(system_info, 'broken')).to eq(86_400)
    end
  end

  describe '.gpu_total' do
    it 'returns the default GPU total when system_info is nil' do
      expect(described_class.gpu_total(nil)).to eq(1)
    end

    it 'returns gpu_total using symbol keys' do
      system_info = {
        gpu_total: 4
      }

      expect(described_class.gpu_total(system_info)).to eq(4)
    end

    it 'returns gpu_total using string keys' do
      system_info = {
        'gpu_total' => 8
      }

      expect(described_class.gpu_total(system_info)).to eq(8)
    end

    it 'returns the default GPU total when gpu_total is missing' do
      system_info = {
        nodes: []
      }

      expect(described_class.gpu_total(system_info)).to eq(1)
    end
  end
end
