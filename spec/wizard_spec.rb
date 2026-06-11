# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/services/interactive_wizard'

RSpec.describe AlcesJob::Services::InteractiveWizard do
  subject(:wizard) { described_class.new }

  describe '#slurm_time_to_seconds' do
    it 'converts zero time to zero seconds' do
      expect(wizard.slurm_time_to_seconds('0-00:00:00')).to eq(0)
    end

    it 'converts days to seconds' do
      expect(wizard.slurm_time_to_seconds('1-00:00:00')).to eq(86_400)
    end

    it 'converts days, hours, minutes and seconds to seconds' do
      expect(wizard.slurm_time_to_seconds('1-01:01:01')).to eq(90_061)
    end
  end

  describe '#human_readable_time' do
    it 'returns days only' do
      expect(wizard.human_readable_time('7-00:00:00')).to eq('7 days')
    end

    it 'returns hours only' do
      expect(wizard.human_readable_time('0-02:00:00')).to eq('2 hours')
    end

    it 'returns minutes only' do
      expect(wizard.human_readable_time('0-00:30:00')).to eq('30 minutes')
    end

    it 'returns seconds only' do
      expect(wizard.human_readable_time('0-00:00:45')).to eq('45 seconds')
    end

    it 'returns combined readable time' do
      expect(wizard.human_readable_time('1-02:30:15')).to eq(
        '1 days, 2 hours, 30 minutes, 15 seconds'
      )
    end
  end

  describe '#slurm_time_to_seconds' do
    it 'converts D-HH:MM:SS into seconds' do
      expect(wizard.slurm_time_to_seconds('1-01:01:01')).to eq(90_061)
    end
  end

  describe '#normalize_slurm_time' do
    it 'converts integer seconds into D-HH:MM:SS format' do
      expect(wizard.normalize_slurm_time(10_800)).to eq('0-03:00:00')
    end

    it 'converts one day of seconds into D-HH:MM:SS format' do
      expect(wizard.normalize_slurm_time(86_400)).to eq('1-00:00:00')
    end

    it 'converts days, hours, minutes and seconds correctly' do
      expect(wizard.normalize_slurm_time(90_061)).to eq('1-01:01:01')
    end

    it 'adds zero days to HH:MM:SS strings' do
      expect(wizard.normalize_slurm_time('03:00:00')).to eq('0-03:00:00')
    end

    it 'leaves already-normalized Slurm time unchanged' do
      expect(wizard.normalize_slurm_time('2-12:30:00')).to eq('2-12:30:00')
    end

    it 'returns unusual string values unchanged' do
      expect(wizard.normalize_slurm_time('invalid')).to eq('invalid')
    end
  end

  describe '#valid_slurm_time?' do
    it 'accepts valid time below the max time' do
      expect(wizard.valid_slurm_time?('1-00:00:00', '7-00:00:00')).to be true
    end

    it 'accepts valid time equal to the max time' do
      expect(wizard.valid_slurm_time?('7-00:00:00', '7-00:00:00')).to be true
    end

    it 'rejects time above the max time' do
      expect(wizard.valid_slurm_time?('8-00:00:00', '7-00:00:00')).to be false
    end

    it 'rejects nil time' do
      expect(wizard.valid_slurm_time?(nil, '7-00:00:00')).to be false
    end

    it 'rejects empty time' do
      expect(wizard.valid_slurm_time?('', '7-00:00:00')).to be false
    end

    it 'rejects whitespace-only time' do
      expect(wizard.valid_slurm_time?('   ', '7-00:00:00')).to be false
    end

    it 'rejects time without day section' do
      expect(wizard.valid_slurm_time?('01:00:00', '7-00:00:00')).to be false
    end

    it 'rejects time with invalid hours' do
      expect(wizard.valid_slurm_time?('0-24:00:00', '7-00:00:00')).to be false
    end

    it 'rejects time with invalid minutes' do
      expect(wizard.valid_slurm_time?('0-01:60:00', '7-00:00:00')).to be false
    end

    it 'rejects time with invalid seconds' do
      expect(wizard.valid_slurm_time?('0-01:00:60', '7-00:00:00')).to be false
    end

    it 'rejects text input' do
      expect(wizard.valid_slurm_time?('hello', '7-00:00:00')).to be false
    end
  end
end
