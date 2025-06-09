# frozen_string_literal: true

require 'yaml'
require 'factory_bot'

module Yass
  # YAML Seed Parser - Converts YAML configurations to FactoryBot calls
  #
  # Supports:
  # - FactoryBot factory creation with traits and associations
  # - SeedHelpers method calls
  # - Reference resolution (using @variable_name)
  # - Bulk creation and relationship management
  # - ID preservation for external tools
  # - Automatic locking strategy application

  class Core
    attr_reader :context, :created_objects

    def initialize(delegate_context = nil)
      @delegate_context = delegate_context
      @context = {} # Store created objects for reference
      @created_objects = []
      @reference_resolver = ReferenceResolver.new(@context, self)
      @yaml_context = 'Reference Data' # Default context for registry entries
    end

    def parse_file(yaml_file_path)
      # Check if file exists
      unless File.exist?(yaml_file_path)
        raise ParsingError.new(
          'The YAML file could not be found at the specified location.',
          file_path: yaml_file_path,
          error_type: :file_not_found,
          suggestions: [
            "Check that the file path is correct: #{yaml_file_path}",
            'Make sure the file exists in the expected directory',
            'Verify you have permission to read the file'
          ]
        )
      end

      # Load and validate YAML syntax
      yaml_content = load_and_validate_yaml(yaml_file_path)

      # Validate YAML structure
      validate_yaml_structure(yaml_content, yaml_file_path)

      Yass.configuration.logger.info("📄 Parsing YAML seed file: #{File.basename(yaml_file_path)}")

      # Process in dependency order
      process_yaml_content(yaml_content, yaml_file_path)

      Yass.configuration.logger.info("✅ Created #{@created_objects.count} objects from YAML")
      @created_objects
    rescue ParsingError => e
      # Re-raise our custom errors as-is
      raise e
    rescue StandardError => e
      # Wrap unexpected errors with helpful context
      raise ParsingError.new(
        "An unexpected error occurred while processing the YAML file: #{e.message}",
        file_path: yaml_file_path,
        error_type: :unexpected,
        suggestions: [
          'Check the YAML file for syntax errors',
          'Verify all required sections are present',
          'Contact support if the error persists'
        ]
      )
    end

    # Helper method to get line number for the current item being processed
    # Made public so ReferenceResolver can access it
    def get_current_item_line_number
      return nil unless @current_model_type

      if @current_item_index.nil?
        # For bulk creation or single hash items
        find_line_number_for_key(@current_model_type, 'data')
      else
        # For array items, try to find the specific list item
        find_line_number_for_list_item("#{@current_model_type}", @current_item_index) ||
          find_line_number_for_key(@current_model_type, 'data')
      end
    end

    private

    def load_and_validate_yaml(yaml_file_path)
      # Read the file content to track line numbers
      @yaml_lines = File.readlines(yaml_file_path)
      @yaml_file_path = yaml_file_path

      YAML.load_file(yaml_file_path)
    rescue Psych::SyntaxError => e
      raise ParsingError.new(
        "The YAML file contains syntax errors: #{e.problem}",
        file_path: yaml_file_path,
        error_type: :yaml_syntax,
        line_number: e.line,
        column_number: e.column,
        suggestions: [
          'Check for missing colons (:) after keys',
          'Verify proper indentation (use spaces, not tabs)',
          'Make sure quotes are properly closed',
          'Check for missing dashes (-) before list items',
          'Use a YAML validator online to check your syntax'
        ]
      )
    rescue StandardError => e
      raise ParsingError.new(
        "Could not read the YAML file: #{e.message}",
        file_path: yaml_file_path,
        error_type: :file_read,
        suggestions: [
          'Check file permissions',
          'Verify the file is not corrupted',
          'Make sure the file is saved as UTF-8 encoding'
        ]
      )
    end

    def validate_yaml_structure(content, file_path)
      unless content.is_a?(Hash)
        raise ParsingError.new(
          'YAML file must contain a hash/dictionary at the root level.',
          file_path: file_path,
          error_type: :invalid_structure,
          suggestions: [
            'Make sure the YAML file starts with key-value pairs',
            'Check that the indentation is correct throughout the file',
            'Verify there are no syntax errors that would cause misinterpretation'
          ]
        )
      end

      # Validate that at least one processable section exists
      valid_sections = %w[data] + content.keys.reject { |k| k == 'metadata' }
      return unless valid_sections.empty?

      raise ParsingError.new(
        "YAML file must contain at least a 'data' section or other model sections.",
        file_path: file_path,
        error_type: :no_data_sections,
        suggestions: [
          "Add a 'data:' section with your model definitions",
          'Make sure section names are not indented (they should be at the root level)',
          'Check the example YAML files for proper structure'
        ]
      )
    end

    # Helper method to find the line number where a YAML key appears
    def find_line_number_for_key(key, section = nil)
      return nil unless @yaml_lines

      @yaml_lines.each_with_index do |line, index|
        # Look for the key at the beginning of a line (accounting for indentation)
        if section
          # Look for section first, then key within that section
          if line.strip == "#{section}:" || line.strip.start_with?("#{section}:")
            # Found section, now look for key in subsequent lines
            start_looking = index + 1
            @yaml_lines[start_looking..-1].each_with_index do |sub_line, sub_index|
              if sub_line.strip == "#{key}:" || sub_line.strip.start_with?("#{key}:")
                return start_looking + sub_index + 1
              end
              # Stop if we hit another top-level section
              break if sub_line.match(/^\w+:/) && !sub_line.start_with?('  ')
            end
          end
        elsif line.strip == "#{key}:" || line.strip.start_with?("#{key}:")
          # Look for key at any level
          return index + 1
        end
      end

      nil
    end

    # Helper method to find line number for items in a list
    def find_line_number_for_list_item(section, item_index)
      return nil unless @yaml_lines

      section_found = false
      list_item_count = 0

      @yaml_lines.each_with_index do |line, index|
        if line.strip == "#{section}:" || line.strip.start_with?("#{section}:")
          section_found = true
          next
        end

        next unless section_found

        # Look for list items (lines starting with -)
        if line.strip.start_with?('- ')
          return index + 1 if list_item_count == item_index

          list_item_count += 1
        end
        # Stop if we hit another top-level section
        break if line.match(/^\w+:/) && !line.start_with?('  ')
      end

      nil
    end

    def process_yaml_content(content, _file_path = nil)
      # Process metadata first (if present)
      process_metadata(content['metadata']) if content['metadata']

      # Process data section
      process_section(content['data']) if content['data']

      # Process custom sections
      content.each do |section_name, section_data|
        next if %w[metadata data].include?(section_name)

        process_section(section_data)
      end
    end

    def process_metadata(metadata)
      @yaml_context = metadata['context'] if metadata['context']
    end

    def process_section(section_data)
      return unless section_data.is_a?(Hash)

      section_data.each do |model_type, items|
        process_model_items(model_type, items)
      end
    end

    def process_model_items(model_type, items)
      case items
      when Array
        items.each_with_index do |item, index|
          # Store current context for error reporting
          @current_model_type = model_type
          @current_item_index = index
          create_single_item(model_type, item)
        end
      when Hash
        if items['bulk_create']
          @current_model_type = model_type
          @current_item_index = nil
          create_bulk_items(model_type, items)
        else
          @current_model_type = model_type
          @current_item_index = nil
          create_single_item(model_type, items)
        end
      end
    end

    def create_single_item(model_type, item_config)
      # Validate item configuration
      validate_item_config(model_type, item_config)

      strategy = determine_creation_strategy(model_type, item_config)

      case strategy
      when :factory_bot
        create_with_factory_bot(model_type, item_config)
      when :seed_helper
        create_with_seed_helper(model_type, item_config)
      when :custom_method
        create_with_custom_method(model_type, item_config)
      else
        line_number = get_current_item_line_number
        raise ParsingError.new(
          "Unknown creation strategy '#{strategy}' for model type '#{model_type}'.",
          file_path: @yaml_file_path,
          error_type: :invalid_strategy,
          line_number: line_number,
          suggestions: [
            "Use 'factory:' to specify a FactoryBot factory",
            "Use 'method:' to call a seed helper method",
            "Use 'custom_method:' for custom creation methods"
          ]
        )
      end
    rescue ParsingError => e
      # Re-raise our custom errors
      raise e
    rescue StandardError => e
      # Wrap other errors with context
      line_number = get_current_item_line_number
      raise ParsingError.new(
        "Failed to create #{model_type} object: #{e.message}",
        file_path: @yaml_file_path,
        error_type: :creation_failed,
        line_number: line_number,
        suggestions: [
          'Check that all required attributes are provided',
          'Verify that referenced objects exist (e.g., @account_name)',
          'Make sure the factory name is correct',
          'Check for typos in attribute names'
        ]
      )
    end

    def validate_item_config(model_type, config)
      return if config.is_a?(Hash)

      line_number = get_current_item_line_number
      raise ParsingError.new(
        "Item configuration for '#{model_type}' must be a hash/dictionary.",
        file_path: @yaml_file_path,
        error_type: :invalid_config,
        line_number: line_number,
        suggestions: [
          'Make sure each item is defined with key-value pairs',
          'Check indentation - each item should be properly nested',
          "Example: #{model_type}:\n  factory: #{model_type.to_s.singularize}\n  attributes:\n    name: 'Example'"
        ]
      )
    end

    def determine_creation_strategy(_model_type, config)
      if config['factory']
        :factory_bot
      elsif config['method']
        :seed_helper
      elsif config['custom_method']
        :custom_method
      else
        # Default to FactoryBot if no explicit strategy
        :factory_bot
      end
    end

    def create_with_factory_bot(model_type, config)
      factory_name = (config['factory'] || model_type.to_s.singularize.underscore).to_sym

      # Resolve attributes and references
      attributes = resolve_attributes(config['attributes'] || {})
      traits = resolve_traits(config['traits'] || [])

      # Create the object
      object = FactoryBot.create(factory_name, *traits, **attributes)

      # Store reference if specified
      store_reference(config['ref'], object) if config['ref']

      # Apply post-creation steps
      apply_post_creation_steps(object, config['after_create']) if config['after_create']

      @created_objects << object
      object
    end

    def create_with_seed_helper(model_type, config)
      method_name = config['method'] || "create_#{model_type.to_s.underscore}"

      # Check if method exists on delegate context, seed helpers module, or self
      target = find_method_target(method_name)

      unless target
        raise ParsingError.new(
          "SeedHelper method '#{method_name}' not found.",
          file_path: @yaml_file_path,
          error_type: :method_not_found,
          suggestions: [
            'Make sure the method exists in your configured seed helpers module',
            'Check the spelling of the method name',
            'Verify the method is accessible from the current context'
          ]
        )
      end

      # Resolve arguments
      arguments = resolve_attributes(config['arguments'] || {})

      # Call the method
      object = target.send(method_name, **arguments)

      # Store reference if specified
      store_reference(config['ref'], object) if config['ref']

      @created_objects << object
      object
    end

    def create_with_custom_method(_model_type, config)
      method_name = config['custom_method']

      unless method_name.is_a?(String)
        raise ParsingError.new(
          'Custom method name must be a string.',
          file_path: @yaml_file_path,
          error_type: :invalid_method_name
        )
      end

      target = find_method_target(method_name)

      unless target
        raise ParsingError.new(
          "Custom method '#{method_name}' not found.",
          file_path: @yaml_file_path,
          error_type: :method_not_found
        )
      end

      arguments = resolve_attributes(config['arguments'] || {})
      object = target.send(method_name, **arguments)

      store_reference(config['ref'], object) if config['ref']

      @created_objects << object
      object
    end

    def find_method_target(method_name)
      if @delegate_context && @delegate_context.respond_to?(method_name)
        @delegate_context
      elsif Yass.configuration.seed_helpers_module &&
            Yass.configuration.seed_helpers_module.respond_to?(method_name)
        Yass.configuration.seed_helpers_module
      elsif respond_to?(method_name)
        self
      end
    end

    def resolve_attributes(attributes)
      @reference_resolver.resolve_hash(attributes)
    end

    def resolve_traits(traits)
      traits.map { |trait| @reference_resolver.resolve_value(trait) }
    end

    def store_reference(ref_key, object)
      if ref_key.start_with?('@')
        # Local reference (@variable)
        @context[ref_key] = object
        Yass.configuration.logger.debug("📝 Stored local reference: #{ref_key} -> #{object.class.name}##{object.id}")
      else
        # Registry reference
        Registry.register(ref_key, object, nil, @yaml_context)
      end
    end

    def apply_post_creation_steps(object, after_create_config)
      return unless after_create_config.is_a?(Hash)

      after_create_config.each do |action, value|
        case action
        when 'call'
          if value.is_a?(Array)
            value.each { |method| object.send(method) }
          else
            object.send(value)
          end
        when 'set'
          value.each { |attr, val| object.send("#{attr}=", @reference_resolver.resolve_value(val)) }
          object.save!
        end
      end
    end

    def create_bulk_items(model_type, config)
      # Implementation for bulk creation would go here
      # This is a complex feature that would need careful extraction
      raise NotImplementedError, 'Bulk creation not yet implemented in gem version'
    end
  end

  # Helper class for resolving references in YAML
  class ReferenceResolver
    def initialize(context, parser_context = nil)
      @context = context
      @parser_context = parser_context # Reference to parser for line tracking
    end

    def resolve_value(value)
      case value
      when /^@(\w+)$/ # @variable_name
        resolve_reference(::Regexp.last_match(1))
      when /^@(\w+)\.(\w+)$/ # @variable_name.attribute
        resolve_attribute_reference(::Regexp.last_match(1), ::Regexp.last_match(2))
      when /^registry\.(\w+)\.(\w+)$/ # registry.accounts.facility_1
        resolve_registry_reference(::Regexp.last_match(1), ::Regexp.last_match(2))
      when String
        # Check for Ruby code blocks and string interpolation
        resolve_ruby_code(value)
      when Hash
        resolve_hash(value)
      when Array
        value.map { |item| resolve_value(item) }
      else
        value
      end
    end

    def resolve_hash(hash)
      resolved = {}
      hash.each do |key, value|
        resolved[key] = resolve_value(value)
      end
      resolved
    end

    private

    def resolve_reference(ref_name)
      ref_key = "@#{ref_name}"
      object = @context[ref_key]
      unless object
        available_refs = @context.keys.join(', ')
        available_text = available_refs.empty? ? 'No references are currently available.' : "Available references: #{available_refs}"

        line_number = @parser_context&.get_current_item_line_number
        file_path = @parser_context&.instance_variable_get(:@yaml_file_path)

        raise ParsingError.new(
          "Reference '@#{ref_name}' not found in the current context.",
          file_path: file_path,
          error_type: :reference_not_found,
          line_number: line_number,
          suggestions: [
            "Check that you've defined the reference with 'ref: @#{ref_name}' in an earlier item",
            'Make sure the spelling matches exactly (references are case-sensitive)',
            "Verify the item with this reference is created before it's used",
            available_text
          ]
        )
      end
      object
    end

    def resolve_attribute_reference(ref_name, attribute)
      object = resolve_reference(ref_name)
      unless object.respond_to?(attribute.to_s)
        available_methods = object.methods.grep(/^[a-z]/).first(10).join(', ')
        line_number = @parser_context&.get_current_item_line_number
        file_path = @parser_context&.instance_variable_get(:@yaml_file_path)

        raise ParsingError.new(
          "Attribute '#{attribute}' not found on object '@#{ref_name}'.",
          file_path: file_path,
          error_type: :attribute_not_found,
          line_number: line_number,
          suggestions: [
            'Check the spelling of the attribute name',
            'Verify the object has this attribute/method',
            'Common attributes include: id, name, created_at',
            "Available methods on this object include: #{available_methods}"
          ]
        )
      end
      object.send(attribute)
    end

    def resolve_registry_reference(registry_type, key)
      # Special case for dates - not stored as ActiveRecord objects
      if registry_type == 'dates'
        resolve_date_reference(key)
      else
        # Automatically singularize registry type for consistency
        singular_registry_type = registry_type.singularize
        prefixed_key = "#{singular_registry_type}.#{key}"

        if Registry.exists?(prefixed_key)
          Registry.get(prefixed_key)
        elsif Registry.exists?(key)
          # Try direct key lookup for backwards compatibility
          Registry.get(key)
        elsif registry_type != singular_registry_type
          # If the original registry_type was plural, try the original form too
          original_prefixed_key = "#{registry_type}.#{key}"
          if Registry.exists?(original_prefixed_key)
            Registry.get(original_prefixed_key)
          else
            raise_registry_not_found_error(registry_type, key)
          end
        else
          raise_registry_not_found_error(registry_type, key)
        end
      end
    end

    def resolve_date_reference(key)
      case key
      # Basic dates
      when 'today'
        DateHelper.current_date
      when 'tomorrow'
        DateHelper.add_days(DateHelper.current_date, 1)
      when 'next_week'
        DateHelper.add_weeks(DateHelper.current_date, 1)
      when 'next_month'
        DateHelper.add_months(DateHelper.current_date, 1)

      # Next weekdays (Monday = 1, Sunday = 0)
      when 'next_monday'
        DateHelper.next_occurring(:monday)
      when 'next_tuesday'
        DateHelper.next_occurring(:tuesday)
      when 'next_wednesday'
        DateHelper.next_occurring(:wednesday)
      when 'next_thursday'
        DateHelper.next_occurring(:thursday)
      when 'next_friday'
        DateHelper.next_occurring(:friday)
      when 'next_saturday'
        DateHelper.next_occurring(:saturday)
      when 'next_sunday'
        DateHelper.next_occurring(:sunday)

      # This week's days (Monday through Sunday)
      when 'this_week_monday'
        DateHelper.beginning_of_week(:monday)
      when 'this_week_tuesday'
        DateHelper.add_days(DateHelper.beginning_of_week(:monday), 1)
      when 'this_week_wednesday'
        DateHelper.add_days(DateHelper.beginning_of_week(:monday), 2)
      when 'this_week_thursday'
        DateHelper.add_days(DateHelper.beginning_of_week(:monday), 3)
      when 'this_week_friday'
        DateHelper.add_days(DateHelper.beginning_of_week(:monday), 4)
      when 'this_week_saturday'
        DateHelper.add_days(DateHelper.beginning_of_week(:monday), 5)
      when 'this_week_sunday'
        DateHelper.add_days(DateHelper.beginning_of_week(:monday), 6)

      # Month dates
      when 'first_of_this_month'
        DateHelper.beginning_of_month(DateHelper.current_date)
      when 'first_of_next_month'
        DateHelper.beginning_of_month(DateHelper.add_months(DateHelper.current_date, 1))

      # Legacy date keys for backward compatibility
      when 'monday_of_this_week'
        DateHelper.beginning_of_week(:monday)
      when 'fifteenth_of_this_month'
        DateHelper.add_days(DateHelper.beginning_of_month(DateHelper.current_date), 14)
      else
        raise ParsingError.new(
          "Unknown date key '#{key}' in registry.dates.#{key}.",
          error_type: :invalid_date_key,
          suggestions: [
            'Basic dates: today, tomorrow, next_week, next_month',
            'Next weekdays: next_monday, next_tuesday, ..., next_sunday',
            'This week: this_week_monday, this_week_tuesday, ..., this_week_sunday',
            'Month dates: first_of_this_month, first_of_next_month',
            'Legacy: monday_of_this_week, fifteenth_of_this_month',
            'Example: registry.dates.next_friday'
          ]
        )
      end
    end

    def raise_registry_not_found_error(registry_type, key)
      available_keys = Registry.all_keys.first(10)
      available_text = available_keys.any? ? "Some available keys: #{available_keys.join(', ')}" : 'No registry keys are available'

      raise ParsingError.new(
        "Registry reference 'registry.#{registry_type}.#{key}' not found.",
        error_type: :registry_key_not_found,
        suggestions: [
          'Check the spelling of the registry type and key',
          'Make sure reference data has been loaded first',
          "Try using 'registry.#{registry_type.singularize}.#{key}' instead",
          available_text
        ]
      )
    end

    def resolve_ruby_code(value)
      # Handle both standalone Ruby code [[code]] and string interpolation with Ruby code
      if value.match(/^\[\[(.+)\]\]$/)
        # Standalone Ruby code block - return the result directly
        code = ::Regexp.last_match(1)
        execute_ruby_code(code)
      elsif value.include?('[[') && value.include?(']]')
        # String interpolation with Ruby code blocks
        value.gsub(/\[\[(.+?)\]\]/) do |_match|
          code = ::Regexp.last_match(1)
          result = execute_ruby_code(code)
          result.to_s
        end
      else
        # No Ruby code found, return as-is
        value
      end
    end

    def execute_ruby_code(code)
      # Execute the Ruby code and return the result
      result = eval(code)
      Yass.configuration.logger.debug("🔧 Executed Ruby code: #{code} → #{result}")
      result
    rescue StandardError => e
      line_number = @parser_context&.get_current_item_line_number
      file_path = @parser_context&.instance_variable_get(:@yaml_file_path)

      raise ParsingError.new(
        "Error executing Ruby code '#{code}': #{e.message}",
        file_path: file_path,
        error_type: :ruby_execution_error,
        line_number: line_number,
        suggestions: [
          'Check the Ruby syntax in the code block',
          'Make sure all variables and methods are available',
          'Verify the code returns a valid value',
          'Consider using simpler expressions or pre-defined references'
        ]
      )
    end
  end
end
