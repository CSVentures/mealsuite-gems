# frozen_string_literal: true

module Yass
  class SeedRegistryController < Yass::ApplicationController
    include ActionView::Helpers::NumberHelper

    def index
      @model_filter = params[:model_filter]
      @search_term = params[:search]

      # Start with all entries
      @entries = base_query

      # Apply model filter
      if @model_filter.present? && @model_filter != 'all'
        @entries = @entries.where(object_class: @model_filter)
      end

      # Apply search filter
      if @search_term.present?
        @entries = @entries.where('key ILIKE ?', "%#{@search_term}%")
      end

      # Order and paginate
      @entries = @entries.order(:object_class, :key)
      
      if params[:per_page].present?
        per_page = [params[:per_page].to_i, 1000].min # Cap at 1000
        @entries = @entries.limit(per_page).offset(params[:offset].to_i)
      else
        @entries = @entries.limit(50) # Default limit
      end

      # Get statistics for the sidebar
      @total_count = base_query.count
      @model_counts = base_query.group(:object_class).count.sort

      respond_to do |format|
        format.html
        format.json do
          render json: {
            entries: @entries.map { |entry| entry_json(entry) },
            total_count: @total_count,
            model_counts: @model_counts
          }
        end
      end
    end

    def show
      @entry = registry_model_class.find(params[:id])
      @object = @entry.get_object
      @object_exists = @entry.object_exists?

      # If object exists, get its attributes and methods for inspection
      if @object_exists && @object
        @object_attributes = @object.attributes
        @object_methods = get_useful_methods(@object)
        @associations = get_associations(@object)
      end

      respond_to do |format|
        format.html
        format.json do
          render json: {
            entry: entry_json(@entry),
            object_exists: @object_exists,
            object_attributes: @object_attributes,
            object_methods: @object_methods&.transform_values { |v| safe_value_preview(v) },
            associations: @associations&.transform_values { |v| safe_value_preview(v) }
          }
        end
      end
    end

    def stats
      stats = {
        total_entries: base_query.count,
        model_counts: base_query.group(:object_class).count.sort,
        context_counts: base_query.group(:context).count.sort,
        recent_entries: base_query.order(created_at: :desc).limit(10).map { |entry| entry_json_basic(entry) }
      }

      respond_to do |format|
        format.json { render json: stats }
      end
    end

    def clean_orphaned
      if registry_model_class.respond_to?(:clean_orphaned_entries!)
        deleted_count = registry_model_class.clean_orphaned_entries!
        render json: { 
          message: "Cleaned #{deleted_count} orphaned entries",
          deleted_count: deleted_count 
        }
      else
        render json: { message: 'Clean orphaned method not available' }, status: :not_implemented
      end
    end

    private

    def registry_model_class
      Yass.configuration.registry_model_class
    end

    def base_query
      if registry_model_class && registry_model_class.table_exists?
        registry_model_class.all
      else
        # Return empty relation if table doesn't exist
        registry_model_class&.none || []
      end
    end

    def entry_json(entry)
      {
        id: entry.id,
        key: entry.key,
        object_class: entry.object_class,
        object_id: entry.object_id,
        description: entry.description,
        context: entry.context,
        created_at: entry.created_at,
        object_exists: entry.object_exists?,
        object_preview: entry.object_preview
      }
    end

    def entry_json_basic(entry)
      {
        id: entry.id,
        key: entry.key,
        object_class: entry.object_class,
        object_id: entry.object_id,
        description: entry.description,
        context: entry.context,
        created_at: entry.created_at
      }
    end


    def get_useful_methods(object)
      return {} unless object

      methods_to_try = %w[name title description display_name to_s]
      result = {}

      methods_to_try.each do |method_name|
        if object.respond_to?(method_name)
          begin
            value = object.public_send(method_name)
            result[method_name] = value
          rescue => e
            result[method_name] = "Error: #{e.message}"
          end
        end
      end

      result
    end

    def get_associations(object)
      return {} unless object&.class&.respond_to?(:reflect_on_all_associations)

      associations = {}
      
      # Get a few key associations (limit to avoid performance issues)
      object.class.reflect_on_all_associations.first(5).each do |association|
        begin
          if association.collection?
            value = object.public_send(association.name).limit(3).pluck(:id)
            associations[association.name.to_s] = "IDs: #{value.join(', ')}" if value.any?
          else
            associated_object = object.public_send(association.name)
            if associated_object
              associations[association.name.to_s] = "#{associated_object.class.name}##{associated_object.id}"
            end
          end
        rescue => e
          associations[association.name.to_s] = "Error: #{e.message}"
        end
      end

      associations
    end

    def safe_value_preview(value)
      case value
      when String
        value.length > 100 ? "#{value[0..97]}..." : value
      when ActiveRecord::Base
        "#{value.class.name}##{value.id}"
      when Array
        value.length > 5 ? "Array[#{value.length}] #{value.first(3).inspect}..." : value.inspect
      when Hash
        value.keys.length > 5 ? "Hash[#{value.keys.length}] #{value.keys.first(3).inspect}..." : value.inspect
      else
        value.inspect
      end
    rescue
      value.to_s
    end
  end
end