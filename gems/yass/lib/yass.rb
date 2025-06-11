# frozen_string_literal: true

require_relative 'yass/version'
require_relative 'yass/configuration'
require_relative 'yass/errors'
require_relative 'yass/registry'
require_relative 'yass/seed_registry_entry'
require_relative 'yass/date_helper'
require_relative 'yass/core'
require_relative 'yass/loader'

module Yass
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    def reset_configuration!
      self.configuration = Configuration.new
    end

    # Convenience method to check if YASS is actively processing seed files
    def seeding_active?
      configuration&.seeding_active == true
    end
  end

  # Initialize with default configuration
  configure
end
