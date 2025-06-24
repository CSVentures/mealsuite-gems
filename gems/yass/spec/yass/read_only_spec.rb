# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Read-Only Mode' do
  let(:parser) { Yass::Core.new }
  let(:temp_yaml_file) { Tempfile.new(['test_seed', '.yml']) }
  let(:mock_object) do
    double('MockObject',
           id: 123,
           name: 'Test Object',
           active: true,
           persisted?: true,
           class: double(name: 'MockObject'))
  end

  before do
    # Mock FactoryBot
    allow(FactoryBot).to receive(:create).and_return(mock_object)
    
    # Mock ActiveRecord::Base and ActiveRecord::Rollback
    stub_const('ActiveRecord', Module.new)
    stub_const('ActiveRecord::Base', Class.new)
    stub_const('ActiveRecord::Rollback', Class.new(StandardError))
    
    # Clear registry
    Yass::Registry.clear_all!
  end

  after do
    temp_yaml_file.close
    temp_yaml_file.unlink
  end

  describe 'Yass::Core#parse_file with read_only option' do
    let(:yaml_content) do
      <<~YAML
        data:
          test_objects:
            - factory: test_object
              attributes:
                name: "Test Object"
                active: true
              ref: "@test_obj"
      YAML
    end

    before do
      temp_yaml_file.write(yaml_content)
      temp_yaml_file.close
    end

    it 'processes YAML content in read-only mode without persisting' do
      # Mock the transaction to simulate rollback behavior
      rollback_called = false
      allow(ActiveRecord::Base).to receive(:transaction) do |&block|
        begin
          block.call
        rescue ActiveRecord::Rollback
          rollback_called = true
        end
      end

      objects = parser.parse_file(temp_yaml_file.path, read_only: true)
      
      expect(objects).to be_an(Array)
      expect(objects.length).to eq(1)
      expect(objects.first).to eq(mock_object)
      expect(rollback_called).to be true
    end

    it 'returns created objects even in read-only mode' do
      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      
      objects = parser.parse_file(temp_yaml_file.path, read_only: true)
      expect(objects).to be_an(Array)
      expect(objects.length).to eq(1)
    end

    it 'processes normally when read_only is false' do
      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      
      objects = parser.parse_file(temp_yaml_file.path, read_only: false)
      expect(objects).to be_an(Array)
      expect(objects.length).to eq(1)
    end

    it 'defaults to non-read-only mode when option not provided' do
      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      
      objects = parser.parse_file(temp_yaml_file.path)
      expect(objects).to be_an(Array)
      expect(objects.length).to eq(1)
    end
  end

  describe 'Yass::Loader.load_test_suite with read_only option' do
    let(:suite_name) { 'test_suite' }
    let(:yaml_file) { File.join(Yass.configuration.yaml_directory, "#{suite_name}.yml") }
    let(:yaml_content) do
      <<~YAML
        data:
          accounts:
            - factory: account
              attributes:
                name: "Test Account"
      YAML
    end

    before do
      # Write the test suite file
      File.write(yaml_file, yaml_content)
    end

    after do
      File.delete(yaml_file) if File.exist?(yaml_file)
    end

    it 'processes test suite in read-only mode' do
      rollback_called = false
      allow(ActiveRecord::Base).to receive(:transaction) do |&block|
        begin
          block.call
        rescue ActiveRecord::Rollback
          rollback_called = true
        end
      end

      objects = Yass::Loader.load_test_suite(suite_name, read_only: true)
      
      expect(objects).to be_an(Array)
      expect(objects.length).to eq(1)
      expect(rollback_called).to be true
    end

    it 'skips export mappings in read-only mode' do
      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      
      # Should not create the export file
      export_file = File.join(Yass.configuration.yaml_directory, "#{suite_name}_id_mappings.json")
      
      Yass::Loader.load_test_suite(suite_name, read_only: true, export_mappings: true)
      
      expect(File.exist?(export_file)).to be false
    end
  end

  describe 'Yass::Loader.load_from_content with read_only option' do
    let(:yaml_content) do
      <<~YAML
        data:
          test_objects:
            - factory: test_object
              attributes:
                name: "Test Object"
      YAML
    end

    it 'processes content in read-only mode' do
      rollback_called = false
      allow(ActiveRecord::Base).to receive(:transaction) do |&block|
        begin
          block.call
        rescue ActiveRecord::Rollback
          rollback_called = true
        end
      end

      objects = Yass::Loader.load_from_content(yaml_content, read_only: true)
      
      expect(objects).to be_an(Array)
      expect(objects.length).to eq(1)
      expect(rollback_called).to be true
    end

    it 'processes content normally when read_only is false' do
      allow(ActiveRecord::Base).to receive(:transaction).and_yield
      
      objects = Yass::Loader.load_from_content(yaml_content, read_only: false)
      expect(objects).to be_an(Array)
      expect(objects.length).to eq(1)
    end
  end
end