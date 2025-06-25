# frozen_string_literal: true

module Yass
  class Engine < ::Rails::Engine
    isolate_namespace Yass

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.assets false
      g.helper false
    end

    # Allow host applications to customize the mount path
    config.yass = ActiveSupport::OrderedOptions.new
    config.yass.mount_path = '/yass'
    config.yass.layout = 'yass/application'

    initializer 'yass.assets.precompile' do |app|
      app.config.assets.precompile += %w[yass/application.css yass/application.js]
    end
  end
end