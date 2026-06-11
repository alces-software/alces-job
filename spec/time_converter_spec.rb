# spec/time_converter_spec.rb

require 'spec_helper'
require_relative '../lib/services/converters/time_converter'

RSpec.describe TimeConverter do
  describe '.to_seconds' do
    context 'when time is HH:MM:SS' do
      it 'converts to seconds' do
        expect(described_class.to_seconds('00:00:00')).to eq(0)
        expect(described_class.to_seconds('00:01:00')).to eq(60)
        expect(described_class.to_seconds('01:00:00')).to eq(3600)
        expect(described_class.to_seconds('01:01:01')).to eq(3661)
      end
    end

    context 'when time includes days' do
      it 'converts days, hours, minutes, and seconds to total seconds' do
        expect(described_class.to_seconds('1-00:00:00')).to eq(86_400)
        expect(described_class.to_seconds('1-01:00:00')).to eq(90_000)
        expect(described_class.to_seconds('2-12:30:15')).to eq(217_815)
      end
    end

    context 'when time has leading/trailing whitespace' do
      it 'handles whitespace correctly' do
        expect(described_class.to_seconds(' 01:01:01 ')).to eq(3661)
      end
    end

    context 'when time is invalid' do
      it 'returns nil' do
        expect(described_class.to_seconds('')).to be_nil
        expect(described_class.to_seconds('abc')).to be_nil
        expect(described_class.to_seconds('1:1:1')).to be_nil
        expect(described_class.to_seconds('01:60:00')).to be_nil
        expect(described_class.to_seconds('01:00:60')).to be_nil
        expect(described_class.to_seconds('1-25:00:00')).to be_nil
      end
    end
  end
end
