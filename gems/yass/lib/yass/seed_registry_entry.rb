# frozen_string_literal: true

module Yass
  # SeedRegistryEntry model for persisting seed registry data in the database
  # Each entry represents a registered object with a unique key
  #
  # This class is only available when ActiveRecord is loaded (in Rails environments)
  if defined?(ActiveRecord::Base)
    class SeedRegistryEntry < ActiveRecord::Base
      self.table_name = 'yass_seed_registry_entries'

      validates :key, presence: true, uniqueness: true
      validates :object_class, presence: true
      validates :object_id, presence: true

      # Get the actual ActiveRecord object
      def get_object
        object_class.constantize.find(object_id)
      rescue NameError, ActiveRecord::RecordNotFound => e
        logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
        logger.error("Failed to load object #{object_class}##{object_id} for key '#{key}': #{e.message}")
        nil
      end

      # Check if the referenced object still exists
      def object_exists?
        get_object.present?
      end

      # Get object preview for display
      def object_preview
        obj = get_object
        return 'Orphaned' unless obj

        if obj.respond_to?(:name) && obj.name.present?
          obj.name
        elsif obj.respond_to?(:title) && obj.title.present?
          obj.title
        elsif obj.respond_to?(:display_name) && obj.display_name.present?
          obj.display_name
        else
          "#{obj.class.name}##{obj.id}"
        end
      rescue StandardError
        'Error'
      end

      # Class method to create from an ActiveRecord object
      def self.create_from_object(key, object, description = nil, context = 'Reference Data')
        create!(
          key: key,
          object_class: object.class.name,
          object_id: object.id,
          description: description,
          context: context
        )
      end

      # Clean up orphaned entries (where the referenced object no longer exists)
      def self.clean_orphaned_entries!
        orphaned_count = 0

        find_each do |entry|
          unless entry.object_exists?
            entry.destroy
            orphaned_count += 1
          end
        end

        logger = defined?(Rails) ? Rails.logger : Logger.new($stdout)
        logger.info("🧹 Cleaned up #{orphaned_count} orphaned registry entries") if orphaned_count > 0
        orphaned_count
      end

      # Get all entries grouped by context
      def self.by_context
        group(:context).count
      end

      # Find entries by object type
      def self.for_object_class(class_name)
        where(object_class: class_name.to_s)
      end

      # Search entries by key pattern
      def self.search_by_key(pattern)
        where('key LIKE ?', "%#{pattern}%")
      end
    end
  end
end
