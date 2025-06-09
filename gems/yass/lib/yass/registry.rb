# frozen_string_literal: true

module Yass
  # Registry provides a unified registry for seed data objects with key validation
  # and duplicate prevention. Objects can be stored in memory or persisted via a model.
  #
  # Usage:
  #   Yass::Registry.register("account.facility_1", account_object)
  #   Yass::Registry.get("account.facility_1")
  #   Yass::Registry.exists?("account.facility_1")
  #
  class Registry
    class << self
      def register(key, object, description = nil, context = 'Reference Data')
        # Validate key format (should be string)
        raise ArgumentError, "Registry key must be a string, got #{key.class}" unless key.is_a?(String)

        unless object.respond_to?(:persisted?)
          raise ArgumentError,
                "Object must respond to :persisted?, got #{object.class}"
        end
        raise ArgumentError, 'Object must be persisted (have an ID)' unless object.persisted?

        # Check for existing registration
        if exists?(key)
          existing_object = get(key)
          if existing_object
            Yass.configuration.logger.info("🔄 Overwriting existing registry key '#{key}' (was #{existing_object.class.name}##{existing_object.id}, now #{object.class.name}##{object.id})")
          end
          # Remove existing entry
          remove(key)
        end

        # Store in registry (either in-memory or via model)
        if registry_model_class
          registry_model_class.create_from_object(key, object, description, context)
        else
          memory_registry[key] = object
        end

        Yass.configuration.logger.info("🔑 Registered: #{key} -> #{object.class.name}##{object.id}#{description ? " (#{description})" : ''} [#{context}]")
        object
      end

      def get(key)
        raise ArgumentError, "Registry key must be a string, got #{key.class}" unless key.is_a?(String)

        if registry_model_class
          entry = registry_model_class.find_by(key: key)
          unless entry
            available_keys = all_keys
            raise ArgumentError, "Registry key '#{key}' not found. Available keys: #{available_keys.join(', ')}"
          end

          object = entry.get_object
          unless object
            # Clean up orphaned entry
            entry.destroy
            raise ArgumentError, "Registry key '#{key}' references a deleted object. Entry removed."
          end

          object
        else
          object = memory_registry[key]
          unless object
            available_keys = all_keys
            raise ArgumentError, "Registry key '#{key}' not found. Available keys: #{available_keys.join(', ')}"
          end
          object
        end
      end

      def exists?(key)
        if registry_model_class
          registry_model_class.exists?(key: key)
        else
          memory_registry.key?(key)
        end
      end

      def remove(key)
        if registry_model_class
          entry = registry_model_class.find_by(key: key)
          entry&.destroy
        else
          memory_registry.delete(key)
        end
      end

      def all_keys
        if registry_model_class
          registry_model_class.pluck(:key)
        else
          memory_registry.keys
        end
      end

      def clear_all!
        if registry_model_class
          registry_model_class.delete_all
        else
          memory_registry.clear
        end
        Yass.configuration.logger.info('🧹 Cleared all registry entries')
      end

      def count
        if registry_model_class
          registry_model_class.count
        else
          memory_registry.size
        end
      end

      def clean_orphaned_entries!
        return unless registry_model_class

        orphaned_count = 0
        registry_model_class.find_each do |entry|
          unless entry.object_exists?
            entry.destroy
            orphaned_count += 1
          end
        end

        Yass.configuration.logger.info("🧹 Cleaned up #{orphaned_count} orphaned registry entries") if orphaned_count > 0
        orphaned_count
      end

      private

      def registry_model_class
        Yass.configuration.registry_model_class
      end

      def memory_registry
        @memory_registry ||= {}
      end
    end
  end
end
