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

  describe 'bulk creation' do
    context 'with valid bulk_create configuration' do
      it 'creates multiple objects using template' do
        yaml_content = <<~YAML
          data:
            menu_items:
              bulk_create:
                count: 3
                template:
                  factory: menu_item
                  attributes:
                    name: "Item {{index}}"
                    day: "{{index + 1}}"
        YAML

        temp_yaml_file.write(yaml_content)
        temp_yaml_file.close

        expect(FactoryBot).to receive(:create).with(:menu_item, 'name' => 'Item 0', 'day' => '1').and_return(mock_object)
        expect(FactoryBot).to receive(:create).with(:menu_item, 'name' => 'Item 1', 'day' => '2').and_return(mock_object)
        expect(FactoryBot).to receive(:create).with(:menu_item, 'name' => 'Item 2', 'day' => '3').and_return(mock_object)

        result = parser.parse_file(temp_yaml_file.path)

        expect(result).to be_an(Array)
        expect(result.size).to eq(3)
      end

      it 'handles mathematical expressions in templates' do
        yaml_content = <<~YAML
          data:
            menu_items:
              bulk_create:
                count: 6
                template:
                  factory: menu_item
                  attributes:
                    week: "{{index / 3 + 1}}"
                    day: "{{index % 3 + 1}}"
        YAML

        temp_yaml_file.write(yaml_content)
        temp_yaml_file.close

        # Expected calculations:
        # index 0: week=1, day=1
        # index 1: week=1, day=2
        # index 2: week=1, day=3
        # index 3: week=2, day=1
        # index 4: week=2, day=2
        # index 5: week=2, day=3

        expect(FactoryBot).to receive(:create).with(:menu_item, 'week' => '1', 'day' => '1').and_return(mock_object)
        expect(FactoryBot).to receive(:create).with(:menu_item, 'week' => '1', 'day' => '2').and_return(mock_object)
        expect(FactoryBot).to receive(:create).with(:menu_item, 'week' => '1', 'day' => '3').and_return(mock_object)
        expect(FactoryBot).to receive(:create).with(:menu_item, 'week' => '2', 'day' => '1').and_return(mock_object)
        expect(FactoryBot).to receive(:create).with(:menu_item, 'week' => '2', 'day' => '2').and_return(mock_object)
        expect(FactoryBot).to receive(:create).with(:menu_item, 'week' => '2', 'day' => '3').and_return(mock_object)

        result = parser.parse_file(temp_yaml_file.path)
        expect(result.size).to eq(6)
      end

      it 'works with references in templates' do
        yaml_content = <<~YAML
          data:
            accounts:
              - factory: account
                attributes:
                  name: "Test Account"
                ref: "@test_account"
            menu_items:
              bulk_create:
                count: 2
                template:
                  factory: menu_item
                  attributes:
                    name: "Item {{index}}"
                    account: "@test_account"
        YAML

        temp_yaml_file.write(yaml_content)
        temp_yaml_file.close

        expect(FactoryBot).to receive(:create).with(:account, 'name' => 'Test Account').and_return(mock_object)
        expect(FactoryBot).to receive(:create).with(:menu_item, 'name' => 'Item 0', 'account' => mock_object).and_return(mock_object)
        expect(FactoryBot).to receive(:create).with(:menu_item, 'name' => 'Item 1', 'account' => mock_object).and_return(mock_object)

        result = parser.parse_file(temp_yaml_file.path)
        expect(result.size).to eq(3) # 1 account + 2 menu items
      end
    end

    context 'with missing template' do
      it 'raises ParsingError with helpful suggestions' do
        yaml_content = <<~YAML
          data:
            menu_items:
              bulk_create:
                count: 3
        YAML

        temp_yaml_file.write(yaml_content)
        temp_yaml_file.close

        expect do
          parser.parse_file(temp_yaml_file.path)
        end.to raise_error(Yass::ParsingError) do |error|
          expect(error.error_type).to eq(:missing_template)
          expect(error.suggestions).to include(match(/Add a template section/))
        end
      end
    end

    context 'with missing count' do
      it 'raises ParsingError with helpful suggestions' do
        yaml_content = <<~YAML
          data:
            menu_items:
              bulk_create:
                template:
                  factory: menu_item
                  attributes:
                    name: "Test Item"
        YAML

        temp_yaml_file.write(yaml_content)
        temp_yaml_file.close

        expect do
          parser.parse_file(temp_yaml_file.path)
        end.to raise_error(Yass::ParsingError) do |error|
          expect(error.error_type).to eq(:missing_count)
          expect(error.suggestions).to include(match(/Add a count field/))
        end
      end
    end

    context 'with invalid template expression' do
      it 'raises ParsingError for syntax errors' do
        yaml_content = <<~YAML
          data:
            menu_items:
              bulk_create:
                count: 2
                template:
                  factory: menu_item
                  attributes:
                    value: "{{index / }}"
        YAML

        temp_yaml_file.write(yaml_content)
        temp_yaml_file.close

        expect do
          parser.parse_file(temp_yaml_file.path)
        end.to raise_error(Yass::ParsingError) do |error|
          expect(error.error_type).to eq(:template_expression_error)
          expect(error.suggestions).to include(match(/Check the syntax/))
        end
      end
    end
  end
end
