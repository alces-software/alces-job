# spec/memory_converter_spec.rb

require 'spec_helper'
require_relative '../lib/services/converters/memory_converter'

RSpec.describe MemoryConverter do
  describe '.to_mb' do
    context 'when input is in MB' do
      it 'returns the value unchanged' do
        expect(described_class.to_mb('512M')).to eq(512)
        expect(described_class.to_mb('512MB')).to eq(512)
      end
    end

    context 'when input is in GB' do
      it 'converts to MB' do
        expect(described_class.to_mb('1G')).to eq(1024)
        expect(described_class.to_mb('2GB')).to eq(2048)
      end
    end

    context 'when input is in TB' do
      it 'converts to MB' do
        expect(described_class.to_mb('1T')).to eq(1_048_576)
        expect(described_class.to_mb('2TB')).to eq(2_097_152)
      end
    end

    context 'when input contains decimals' do
      it 'rounds up before conversion' do
        expect(described_class.to_mb('1.1G')).to eq(2048)
        expect(described_class.to_mb('1.5G')).to eq(2048)
        expect(described_class.to_mb('1.1T')).to eq(2_097_152)
      end
    end

    context 'when input has whitespace or lowercase units' do
      it 'handles them correctly' do
        expect(described_class.to_mb(' 4gb ')).to eq(4096)
        expect(described_class.to_mb('1t')).to eq(1_048_576)
      end
    end

    context 'when input is invalid' do
      it 'returns nil' do
        expect(described_class.to_mb('100')).to be_nil
        expect(described_class.to_mb('100K')).to be_nil
        expect(described_class.to_mb('abc')).to be_nil
        expect(described_class.to_mb('')).to be_nil
      end
    end
  end
end
