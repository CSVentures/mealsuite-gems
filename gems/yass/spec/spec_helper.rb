# frozen_string_literal: true

require 'yass'
require 'rspec'
require 'factory_bot'
require 'tempfile'

# Load shared RSpec configuration
require_relative '../../../shared/rspec_config'

RSpec.configure do |config|

  # Configure Yass for testing
  config.before(:each) do
    Yass.reset_configuration!
    Yass.configure do |conf|
      conf.logger = Logger.new('/dev/null') # Silence logs during tests
      conf.yaml_directory = File.join(Dir.tmpdir, 'yaml_seed_parser_test')
    end

    # Ensure test directory exists
    FileUtils.mkdir_p(Yass.configuration.yaml_directory)
  end

  config.after(:each) do
    # Clean up test directory
    FileUtils.rm_rf(Yass.configuration.yaml_directory) if Dir.exist?(Yass.configuration.yaml_directory)
  end
end
