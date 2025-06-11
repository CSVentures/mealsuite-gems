# frozen_string_literal: true

require 'tempfile'
require 'json'

module Yass
  # YAML Seed Loader - Main interface for loading test suites from YAML files
  #
  # Usage:
  #   Yass::Loader.load_test_suite('basic_facility_test')
  #   Yass::Loader.load_multiple(['basic_facility_test', 'complex_menus_test'])

  class Loader
    class << self
      def load_test_suite(suite_name, options = {})
        yaml_file = File.join(yaml_directory, "#{suite_name}.yml")

        begin
          unless File.exist?(yaml_file)
            raise ParsingError.new(
              "Test suite '#{suite_name}' not found.",
              file_path: yaml_file,
              error_type: :suite_not_found,
              suggestions: [
                "Check the spelling of the suite name: #{suite_name}",
                "Make sure the file exists at: #{yaml_file}",
                'Use Yass::Loader.list_available_suites to see available suites'
              ]
            )
          end

          Yass.configuration.logger.info("🔄 Loading test suite: #{suite_name}")
          start_time = Time.now

          # Pass the calling context as delegate if available
          delegate_context = options[:delegate_context]
          parser = Core.new(delegate_context)
          created_objects = parser.parse_file(yaml_file)

          duration = Time.now - start_time
          Yass.configuration.logger.info("✅ Loaded #{suite_name} (#{created_objects.count} objects in #{duration.round(2)}s)")

          # Export ID mappings if requested
          export_id_mappings(suite_name, created_objects) if options[:export_mappings]

          created_objects
        rescue ParsingError => e
          # Re-raise with suite context
          Yass.configuration.logger.error("❌ Failed to load test suite '#{suite_name}': #{e.user_friendly_message}")
          raise e
        rescue StandardError => e
          # Wrap unexpected errors
          error_msg = "Unexpected error loading test suite '#{suite_name}': #{e.message}"
          Yass.configuration.logger.error(error_msg)
          raise ParsingError.new(
            error_msg,
            file_path: yaml_file,
            error_type: :loader_error,
            suggestions: [
              'Check that the YAML file is valid',
              'Verify all dependencies are available',
              'Contact support if this error persists'
            ]
          )
        end
      end

      def load_multiple(suite_names, options = {})
        results = {}
        total_objects = 0

        suite_names.each do |suite_name|
          Yass.configuration.logger.info("📦 Loading suite #{suite_name} (#{suite_names.index(suite_name) + 1} of #{suite_names.count})")
          objects = load_test_suite(suite_name, options)
          results[suite_name] = objects
          total_objects += objects.count
        end

        Yass.configuration.logger.info("🎉 Loaded #{suite_names.count} test suites with #{total_objects} total objects")
        results
      end

      def load_from_content(yaml_content, options = {})
        delegate_context = options[:delegate_context]
        parser = Core.new(delegate_context)

        # Set seeding flag to indicate YASS is actively processing
        previous_seeding_state = Yass.configuration.seeding_active
        Yass.configuration.seeding_active = true

        begin
          # Parse YAML content
          parsed_yaml = YAML.safe_load(yaml_content)

          # Create temporary file for error reporting
          temp_file = Tempfile.new(['yaml_seed', '.yml'])
          temp_file.write(yaml_content)
          temp_file.close

          # Set up parser with temp file path for error reporting
          parser.instance_variable_set(:@yaml_file_path, temp_file.path)
          parser.instance_variable_set(:@yaml_lines, yaml_content.lines)

          # Wrap entire processing in a database transaction
          transaction_result = nil
          if defined?(ActiveRecord::Base)
            ActiveRecord::Base.transaction do
              # Process the content
              parser.send(:process_yaml_content, parsed_yaml, temp_file.path)
              transaction_result = parser.created_objects
            end
          else
            # Fallback for non-Rails environments
            parser.send(:process_yaml_content, parsed_yaml, temp_file.path)
            transaction_result = parser.created_objects
          end

          temp_file.unlink
          transaction_result
        rescue StandardError => e
          temp_file&.unlink
          raise e
        ensure
          # Always restore previous seeding state
          Yass.configuration.seeding_active = previous_seeding_state
        end
      end

      def list_available_suites
        return [] unless Dir.exist?(yaml_directory)

        Dir.glob(File.join(yaml_directory, '*.yml')).map do |file|
          File.basename(file, '.yml')
        end.sort
      end

      def suite_exists?(suite_name)
        yaml_file = File.join(yaml_directory, "#{suite_name}.yml")
        File.exist?(yaml_file)
      end

      def validate_suite(suite_name)
        yaml_file = File.join(yaml_directory, "#{suite_name}.yml")

        return { valid: false, errors: ["Suite file not found: #{yaml_file}"] } unless File.exist?(yaml_file)

        begin
          validator = SuiteValidator.new
          validator.validate_file(yaml_file)
          { valid: true, errors: [] }
        rescue ParsingError => e
          { valid: false, errors: [e.user_friendly_message] }
        rescue StandardError => e
          { valid: false, errors: ["Validation error: #{e.message}"] }
        end
      end

      def create_suite_template(suite_name, models = %w[accounts users])
        template = {
          'metadata' => {
            'context' => 'Test Data',
            'description' => "Test suite for #{suite_name}"
          },
          'data' => {}
        }

        models.each do |model|
          template['data'][model] = [
            {
              'factory' => model.singularize,
              'attributes' => {
                'name' => "Sample #{model.singularize.humanize}"
              },
              'ref' => "@sample_#{model.singularize}"
            }
          ]
        end

        template
      end

      private

      def yaml_directory
        Yass.configuration.yaml_directory
      end

      def export_id_mappings(suite_name, created_objects)
        mappings = {}
        created_objects.each_with_index do |obj, index|
          if obj.respond_to?(:id)
            key = "#{suite_name}_#{obj.class.name.underscore}_#{index}"
            mappings[key] = obj.id
          end
        end

        export_file = File.join(yaml_directory, "#{suite_name}_id_mappings.json")
        File.write(export_file, JSON.pretty_generate(mappings))
        Yass.configuration.logger.info("💾 Exported ID mappings to: #{export_file}")
      end
    end
  end

  # YAML Suite Validator - validates YAML structure and factory references
  class SuiteValidator
    def validate_file(yaml_file_path)
      unless File.exist?(yaml_file_path)
        raise ParsingError.new(
          'YAML file not found',
          file_path: yaml_file_path,
          error_type: :file_not_found
        )
      end

      content = YAML.load_file(yaml_file_path)
      validate_structure(content, yaml_file_path)
      validate_factories(content, yaml_file_path)
    end

    def validate_content(yaml_content, context_name = 'YAML content')
      content = YAML.safe_load(yaml_content)
      validate_structure(content, context_name)
      validate_factories(content, context_name)
    end

    private

    def validate_structure(content, file_path)
      unless content.is_a?(Hash)
        raise ParsingError.new(
          'YAML root must be a hash/dictionary',
          file_path: file_path,
          error_type: :invalid_structure
        )
      end

      # Check for at least one data section
      data_sections = content.keys.reject { |k| k == 'metadata' }
      return unless data_sections.empty?

      raise ParsingError.new(
        'YAML must contain at least one data section',
        file_path: file_path,
        error_type: :no_data_sections
      )
    end

    def validate_factories(content, file_path)
      # This would validate that referenced factories exist
      # For now, we'll skip this as it requires FactoryBot to be loaded
      # and factories to be defined
    end
  end
end
