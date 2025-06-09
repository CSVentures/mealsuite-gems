# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yass::Registry do
  let(:mock_object) do
    double('MockObject',
           id: 123,
           name: 'Test Object',
           persisted?: true,
           class: double(name: 'MockObject'))
  end

  before do
    described_class.clear_all!
  end

  describe '.register' do
    context 'with in-memory storage' do
      it 'stores object in memory registry' do
        described_class.register('test.key', mock_object)

        expect(described_class.exists?('test.key')).to be true
        expect(described_class.get('test.key')).to eq(mock_object)
      end
    end

    context 'with invalid key' do
      it 'raises ArgumentError for non-string key' do
        expect do
          described_class.register(:symbol_key, mock_object)
        end.to raise_error(ArgumentError, /must be a string/)
      end
    end

    context 'with non-persisted object' do
      let(:unpersisted_object) { double('UnpersistedObject', persisted?: false) }

      it 'raises ArgumentError' do
        expect do
          described_class.register('test.key', unpersisted_object)
        end.to raise_error(ArgumentError, /must be persisted/)
      end
    end
  end

  describe '.get' do
    context 'with existing key' do
      before do
        described_class.register('test.key', mock_object)
      end

      it 'returns the stored object' do
        expect(described_class.get('test.key')).to eq(mock_object)
      end
    end

    context 'with non-existing key' do
      it 'raises ArgumentError with available keys' do
        described_class.register('other.key', mock_object)

        expect do
          described_class.get('nonexistent.key')
        end.to raise_error(ArgumentError, /not found.*Available keys: other\.key/)
      end
    end
  end

  describe '.exists?' do
    it 'returns true for existing keys' do
      described_class.register('test.key', mock_object)
      expect(described_class.exists?('test.key')).to be true
    end

    it 'returns false for non-existing keys' do
      expect(described_class.exists?('nonexistent.key')).to be false
    end
  end

  describe '.clear_all!' do
    it 'removes all registry entries' do
      described_class.register('test.key1', mock_object)
      described_class.register('test.key2', mock_object)

      expect(described_class.count).to eq(2)

      described_class.clear_all!

      expect(described_class.count).to eq(0)
      expect(described_class.exists?('test.key1')).to be false
    end
  end

  describe '.all_keys' do
    it 'returns all registered keys' do
      described_class.register('test.key1', mock_object)
      described_class.register('test.key2', mock_object)

      keys = described_class.all_keys
      expect(keys).to include('test.key1', 'test.key2')
      expect(keys.size).to eq(2)
    end
  end
end
