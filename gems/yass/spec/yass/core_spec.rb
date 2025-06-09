# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yass::Core do
  let(:parser) { described_class.new }
  let(:temp_yaml_file) { Tempfile.new(['test_seed', '.yml']) }

  # Mock ActiveRecord-like object for testing
  let(:mock_object) do
    double('MockObject',
           id: 123,
           name: 'Test Object',
           persisted?: true,
           class: double(name: 'MockObject'))
  end

  before do
    # Mock FactoryBot
    allow(FactoryBot).to receive(:create).and_return(mock_object)

    # Clear registry
    Yass::Registry.clear_all!
  end

  after do
    temp_yaml_file.close
    temp_yaml_file.unlink
  end

  describe '#parse_file' do
    context 'with valid YAML file' do
      it 'parses the file and creates objects' do
        yaml_content = <<~YAML
          data:
            accounts:
              - factory: account
                attributes:
                  name: "Test Account"
                ref: "@test_account"
        YAML

        temp_yaml_file.write(yaml_content)
        temp_yaml_file.close

        result = parser.parse_file(temp_yaml_file.path)

        expect(result).to be_an(Array)
        expect(result.size).to eq(1)
        expect(result.first).to eq(mock_object)
      end
    end

    context 'with invalid YAML syntax' do
      it 'raises a ParsingError with helpful suggestions' do
        yaml_content = <<~YAML
          data:
            accounts:
              - factory: account
                attributes
                  name: "Test Account"
        YAML

        temp_yaml_file.write(yaml_content)
        temp_yaml_file.close

        expect do
          parser.parse_file(temp_yaml_file.path)
        end.to raise_error(Yass::ParsingError) do |error|
          expect(error.error_type).to eq(:yaml_syntax)
          expect(error.suggestions).to include(match(/missing colons/))
        end
      end
    end

    context 'with missing file' do
      it 'raises a ParsingError' do
        expect do
          parser.parse_file('/nonexistent/file.yml')
        end.to raise_error(Yass::ParsingError) do |error|
          expect(error.error_type).to eq(:file_not_found)
        end
      end
    end
  end

  describe '#create_single_item' do
    context 'with FactoryBot strategy' do
      it 'creates object using FactoryBot' do
        config = {
          'factory' => 'account',
          'attributes' => { 'name' => 'Test Account' }
        }

        expect(FactoryBot).to receive(:create).with(:account, 'name' => 'Test Account')

        result = parser.send(:create_single_item, 'accounts', config)
        expect(result).to eq(mock_object)
      end
    end

    context 'with reference storage' do
      it 'stores references in context' do
        config = {
          'factory' => 'account',
          'attributes' => { 'name' => 'Test Account' },
          'ref' => '@test_account'
        }

        parser.send(:create_single_item, 'accounts', config)

        expect(parser.context['@test_account']).to eq(mock_object)
      end
    end
  end
end
