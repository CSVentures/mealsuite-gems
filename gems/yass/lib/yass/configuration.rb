# frozen_string_literal: true

require 'logger'

module Yass
  class Configuration
    attr_accessor :seed_helpers_module, :registry_model_class, :yaml_directory
    attr_reader :logger

    def initialize
      @logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
      @seed_helpers_module = nil
      @registry_model_class = defined?(Yass::SeedRegistryEntry) ? Yass::SeedRegistryEntry : nil
      @yaml_directory = defined?(Rails) ? Rails.root.join('db', 'seed', 'test_suites') : './test_suites'
    end

    def logger=(new_logger)
      @logger = new_logger || Logger.new($stdout)
    end
  end
end
