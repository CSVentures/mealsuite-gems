# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module Yass
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      desc 'Generate YASS seed registry migration and initializer'

      def create_migration
        migration_template(
          'create_yass_seed_registry_entries.rb.erb',
          'db/migrate/create_yass_seed_registry_entries.rb'
        )
      end

      def create_initializer
        template 'yass_initializer.rb.erb', 'config/initializers/yass.rb'
      end

      def add_route
        route 'mount Yass::Engine => "/yass"'
      end

      def show_readme
        readme 'README'
      end

      private

      def migration_version
        # Rails 5.0+ supports migration versioning
        if ActiveRecord::VERSION::MAJOR >= 5
          "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
        else
          ""
        end
      end
    end
  end
end
