# frozen_string_literal: true

module Yass
  class DataSeedingController < Yass::ApplicationController
    skip_before_action :verify_authenticity_token
    include ActionView::Helpers::DateHelper
    include ActionView::Helpers::NumberHelper
    
    def index
      get_seed_configuration
      
      respond_to do |format|
        format.html { render 'index' }
        format.json { render json: @seed_configuration, status: :ok }
      end
    end

    def load_yaml
      allowed = Rails.env.development? || Rails.env.test?
      
      disallowed_databases = %w[touch_production touch_staging touch_dev us_production ca_production us_staging ca_staging us_dev ca_dev]
      current_db_name = ActiveRecord::Base.connection.current_database
      allowed = allowed && disallowed_databases.exclude?(current_db_name)

      unless allowed
        return render json: { message: 'YAML loading not permitted for this environment' }, status: :forbidden
      end
      
      files = params["files"].map{|f| f.start_with?('yass/', '/') ? f : "yass/#{f}" }
      
      if files.empty?
        return render json: { message: 'No files provided' }, status: :bad_request
      end

      # check all files exist, or fail immediately
      files.each do |file_path|
        unless File.exist?(file_path)
          return render json: { message: "File not found: #{file_path}" }, status: :bad_request
        end
      end

      files.each do |file_path|
        # Load using YASS gem
        core = Yass::Core.new
        created_objects = core.parse_file(file_path)
        
        respond_to do |format|
          format.json { 
            render json: { 
              message: 'YAML loaded successfully', 
              objects_created: created_objects.count,
              summary: created_objects.group_by(&:class).transform_values(&:count)
            }, status: :ok 
          }
        end
        
      rescue Yass::ParsingError => e
        Rails.logger.error "YAML loading error: #{e.message}"
        render json: { 
          message: e.message,
          user_friendly_message: e.user_friendly_message,
          error_type: e.error_type,
          suggestions: e.suggestions 
        }, status: :bad_request
      rescue YAML::SyntaxError => e
        render json: { message: "Invalid YAML syntax: #{e.message}" }, status: :bad_request
      rescue => e
        Rails.logger.error "YAML loading error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { message: "Error loading YAML: #{e.message}" }, status: :unprocessable_entity
      end
    end

    def load_yaml_raw
      allowed = Rails.env.development? || Rails.env.test?
      
      disallowed_databases = %w[touch_production touch_staging touch_dev us_production ca_production us_staging ca_staging us_dev ca_dev]
      current_db_name = ActiveRecord::Base.connection.current_database
      allowed = allowed && disallowed_databases.exclude?(current_db_name)

      unless allowed
        return render json: { message: 'YAML loading not permitted for this environment' }, status: :forbidden
      end

      # Get raw YAML content from request body
      yaml_content = request.body.read
      
      if yaml_content.blank?
        return render json: { message: 'No YAML content provided in request body' }, status: :bad_request
      end

      begin
        # Validate YAML syntax first
        YAML.safe_load(yaml_content)
        
        # Create a temporary file to work with the YASS gem
        require 'tempfile'
        temp_file = Tempfile.new(['yaml_raw', '.yml'])
        
        begin
          temp_file.write(yaml_content)
          temp_file.close
          
          # Load using YASS gem
          core = Yass::Core.new
          created_objects = core.parse_file(temp_file.path)
          
          respond_to do |format|
            format.json { 
              render json: { 
                message: 'YAML content loaded successfully', 
                objects_created: created_objects.count,
                summary: created_objects.group_by(&:class).transform_values(&:count)
              }, status: :ok 
            }
          end
          
        ensure
          temp_file.unlink if temp_file
        end
        
      rescue Yass::ParsingError => e
        Rails.logger.error "YAML raw loading error: #{e.message}"
        render json: { 
          message: e.message,
          user_friendly_message: e.user_friendly_message,
          error_type: e.error_type,
          suggestions: e.suggestions 
        }, status: :bad_request
      rescue YAML::SyntaxError => e
        render json: { message: "Invalid YAML syntax: #{e.message}" }, status: :bad_request
      rescue => e
        Rails.logger.error "YAML raw loading error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { message: "Error loading YAML content: #{e.message}" }, status: :unprocessable_entity
      end
    end

    def validate_yaml
      allowed = Rails.env.development? || Rails.env.test?
      
      disallowed_databases = %w[touch_production touch_staging touch_dev us_production ca_production us_staging ca_staging us_dev ca_dev]
      current_db_name = ActiveRecord::Base.connection.current_database
      allowed = allowed && disallowed_databases.exclude?(current_db_name)

      unless allowed
        return render json: { message: 'YAML validation not permitted for this environment' }, status: :forbidden
      end
      
      files = params["files"].map{|f| f.start_with?('yass/', '/') ? f : "yass/#{f}" }
      
      if files.empty?
        return render json: { message: 'No files provided for validation' }, status: :bad_request
      end

      # check all files exist, or fail immediately
      files.each do |file_path|
        unless File.exist?(file_path)
          return render json: { message: "File not found: #{file_path}" }, status: :bad_request
        end
      end

      begin
        results = []
        total_objects = 0
        
        files.each do |file_path|
          # Validate using YASS gem with read_only flag
          core = Yass::Core.new
          validated_objects = core.parse_file(file_path, read_only: true)
          
          summary = validated_objects.group_by(&:class).transform_values(&:count)
          objects_validated = validated_objects.count
          total_objects += objects_validated
          
          results << {
            file: file_path,
            objects_validated: objects_validated,
            summary: summary
          }
        end
        
        respond_to do |format|
          format.json { 
            render json: { 
              message: "Successfully validated #{files.length} file#{files.length == 1 ? '' : 's'} with #{total_objects} total objects", 
              results: results,
              total_objects_validated: total_objects
            }, status: :ok 
          }
        end
        
      rescue Yass::ParsingError => e
        Rails.logger.error "YAML validation error: #{e.message}"
        render json: { 
          message: e.message,
          user_friendly_message: e.user_friendly_message,
          error_type: e.error_type,
          suggestions: e.suggestions 
        }, status: :bad_request
      rescue YAML::SyntaxError => e
        render json: { message: "Invalid YAML syntax: #{e.message}" }, status: :bad_request
      rescue => e
        Rails.logger.error "YAML validation error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { message: "Error validating YAML: #{e.message}" }, status: :unprocessable_entity
      end
    end

    def validate_yaml_raw
      allowed = Rails.env.development? || Rails.env.test?
      
      disallowed_databases = %w[touch_production touch_staging touch_dev us_production ca_production us_staging ca_staging us_dev ca_dev]
      current_db_name = ActiveRecord::Base.connection.current_database
      allowed = allowed && disallowed_databases.exclude?(current_db_name)

      unless allowed
        return render json: { message: 'YAML validation not permitted for this environment' }, status: :forbidden
      end

      # Get raw YAML content from request body
      yaml_content = request.body.read
      
      if yaml_content.blank?
        return render json: { message: 'No YAML content provided in request body' }, status: :bad_request
      end

      begin
        # Validate YAML syntax first
        YAML.safe_load(yaml_content)
        
        # Create a temporary file to work with the YASS gem
        require 'tempfile'
        temp_file = Tempfile.new(['yaml_validate', '.yml'])
        
        begin
          temp_file.write(yaml_content)
          temp_file.close
          
          # Validate using YASS gem with read_only flag
          core = Yass::Core.new
          validated_objects = core.parse_file(temp_file.path, read_only: true)
          
          respond_to do |format|
            format.json { 
              render json: { 
                message: 'YAML content validated successfully', 
                objects_validated: validated_objects.count,
                summary: validated_objects.group_by(&:class).transform_values(&:count)
              }, status: :ok 
            }
          end
          
        ensure
          temp_file.unlink if temp_file
        end
        
      rescue Yass::ParsingError => e
        Rails.logger.error "YAML raw validation error: #{e.message}"
        render json: { 
          message: e.message,
          user_friendly_message: e.user_friendly_message,
          error_type: e.error_type,
          suggestions: e.suggestions 
        }, status: :bad_request
      rescue YAML::SyntaxError => e
        render json: { message: "Invalid YAML syntax: #{e.message}" }, status: :bad_request
      rescue => e
        Rails.logger.error "YAML raw validation error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { message: "Error validating YAML content: #{e.message}" }, status: :unprocessable_entity
      end
    end

    def list_yaml_files
      begin
        yass_dir = Rails.root.join('yass')
        files = []
        
        if Dir.exist?(yass_dir)
          # Find all .yml and .yaml files recursively
          Dir.glob([yass_dir.join('**', '*.yml'), yass_dir.join('**', '*.yaml')]).each do |file_path|
            relative_path = Pathname.new(file_path).relative_path_from(yass_dir).to_s
            file_stats = File.stat(file_path)
            
            files << {
              path: relative_path,
              name: File.basename(file_path),
              size: file_stats.size,
              size_formatted: number_to_human_size(file_stats.size),
              modified_at: file_stats.mtime,
              modified_at_formatted: time_ago_in_words(file_stats.mtime) + ' ago'
            }
          end
        end
        
        # Sort by path for consistent display
        files.sort_by! { |f| f[:path] }
        
        render json: { files: files }, status: :ok
      rescue => e
        Rails.logger.error "Error listing YAML files: #{e.message}"
        render json: { message: "Error listing YAML files: #{e.message}" }, status: :unprocessable_entity
      end
    end

    def get_yaml_file_content
      file_path = params[:file_path]
      
      if file_path.blank?
        return render json: { message: 'File path is required' }, status: :bad_request
      end

      begin
        # Ensure the file path is within the yass directory and safe
        yass_dir = Rails.root.join('yass')
        full_path = yass_dir.join(file_path)
        
        # Security check: ensure the resolved path is still within yass directory
        unless full_path.to_s.start_with?(yass_dir.to_s)
          return render json: { message: 'Access denied: file path outside yass directory' }, status: :forbidden
        end
        
        unless File.exist?(full_path)
          return render json: { message: 'File not found' }, status: :not_found
        end
        
        content = File.read(full_path)
        render json: { content: content }, status: :ok
        
      rescue => e
        Rails.logger.error "Error reading YAML file: #{e.message}"
        render json: { message: "Error reading file: #{e.message}" }, status: :unprocessable_entity
      end
    end

    def upload_yaml_file
      uploaded_file = params[:file]
      
      if uploaded_file.blank?
        return render json: { message: 'No file uploaded' }, status: :bad_request
      end

      begin
        # Validate file type
        unless uploaded_file.content_type.in?(['application/x-yaml', 'text/yaml', 'text/plain', 'application/octet-stream']) || 
               uploaded_file.original_filename.match(/\.(yml|yaml)$/i)
          return render json: { message: 'Invalid file type. Please upload a YAML file (.yml or .yaml)' }, status: :bad_request
        end
        
        # Validate file size (max 10MB)
        max_size = 10.megabytes
        if uploaded_file.size > max_size
          return render json: { 
            message: "File too large. Maximum size is #{number_to_human_size(max_size)}" 
          }, status: :bad_request
        end
        
        # Read file content
        content = uploaded_file.read
        
        # Validate YAML syntax
        begin
          YAML.safe_load(content)
        rescue Psych::SyntaxError => e
          return render json: { 
            message: "Invalid YAML syntax in uploaded file: #{e.message}" 
          }, status: :bad_request
        end
        
        # Return the file content for the textarea
        render json: { 
          content: content,
          filename: uploaded_file.original_filename,
          size: uploaded_file.size,
          size_formatted: number_to_human_size(uploaded_file.size),
          message: 'File uploaded successfully'
        }, status: :ok
        
      rescue => e
        Rails.logger.error "Error uploading YAML file: #{e.message}"
        render json: { message: "Error processing uploaded file: #{e.message}" }, status: :unprocessable_entity
      end
    end

    def run_static_qa_data
      # This would need to be implemented based on the host application's seeding system
      render json: { message: 'Static QA data seeding not implemented in YASS gem' }, status: :not_implemented
    end

    def backup_info
      backup_file_path = Rails.root.join('db', 'seed.dump')
      
      if File.exist?(backup_file_path)
        file_stats = File.stat(backup_file_path)
        
        render json: {
          exists: true,
          size: file_stats.size,
          size_formatted: number_to_human_size(file_stats.size),
          modified_at: file_stats.mtime,
          modified_at_formatted: time_ago_in_words(file_stats.mtime) + ' ago',
          path: 'db/seed.dump'
        }
      else
        render json: {
          exists: false,
          size: 0,
          size_formatted: '-',
          modified_at: nil,
          modified_at_formatted: '-',
          path: 'db/seed.dump'
        }
      end
    rescue => e
      Rails.logger.error "Error getting backup info: #{e.message}"
      render json: { 
        exists: false,
        error: e.message,
        size: 0,
        size_formatted: '-',
        modified_at: nil,
        modified_at_formatted: '-',
        path: 'db/seed.dump'
      }, status: :unprocessable_entity
    end

    def create_backup
      allowed = Rails.env.development? || Rails.env.test?
    
      disallowed_databases = %w[touch_production touch us_production ca_production us_staging ca_staging us_dev ca_dev]
      current_db_name = ActiveRecord::Base.connection.current_database
      allowed = allowed && disallowed_databases.exclude?(current_db_name)

      if allowed
        ActiveRecord::Base.connection.execute("UPDATE seed_configuration SET status = 'Backup Creation Queued', last_run = NOW() AT TIME ZONE 'UTC'")
        Testing::CreateSeedDataBackupJob.perform_async

        respond_to do |format|
          format.json { render json: { message: 'Backup creation initiated successfully' }, status: :ok }
        end
      else
        render json: { message: 'Backup creation not permitted for this environment' }, status: :forbidden
      end
    end

    def restore_backup
      allowed = Rails.env.development? || Rails.env.test?
    
      disallowed_databases = %w[touch_production touch_staging touch_dev us_production ca_production us_staging ca_staging us_dev ca_dev]
      current_db_name = ActiveRecord::Base.connection.current_database
      allowed = allowed && disallowed_databases.exclude?(current_db_name)

      if allowed
        ActiveRecord::Base.connection.execute("UPDATE seed_configuration SET status = 'Backup Restore Queued', last_run = NOW() AT TIME ZONE 'UTC'")
        Testing::ResetSeedDataFromBackupJob.perform_async

        respond_to do |format|
          format.json { render json: { message: 'Restore initiated successfully' }, status: :ok }
        end
      else
        render json: { message: 'Data reseeding not permitted for this environment' }, status: :forbidden
      end
    end

    def status
      get_seed_configuration
      # Ensure timezone-aware formatting for AJAX requests
      if @seed_configuration[:last_run_formatted] && @seed_configuration[:last_run_formatted] != 'N/A'
        # Re-parse to ensure proper timezone handling for AJAX
        begin
          result = ActiveRecord::Base.connection.execute("SELECT last_run FROM seed_configuration ORDER BY last_run DESC LIMIT 1")
          if result.any? && result.first['last_run']
            time = Time.parse(result.first['last_run'].to_s + ' UTC').in_time_zone
            @seed_configuration[:last_run_formatted] = time_ago_in_words(time) + ' ago'
          end
        rescue => e
          Rails.logger.error "Error refreshing timezone for status: #{e.message}"
        end
      end
      
      render json: @seed_configuration
    end

    private

    def get_seed_configuration
      # Try to get seed configuration from the host application if available
      if seed_configuration_table_exists?
        begin
          # Query the seed_configuration table directly
          result = ActiveRecord::Base.connection.execute("SELECT status, last_run FROM seed_configuration ORDER BY last_run DESC LIMIT 1")
          
          if result.any?
            row = result.first
            status = row['status'] || 'Unknown'
            last_run = row['last_run']
            
            # Format the last run time
            last_run_formatted = if last_run
              begin
                # Parse as UTC and convert to local time zone
                time = Time.parse(last_run.to_s + ' UTC').in_time_zone
                time_ago_in_words(time) + ' ago'
              rescue
                last_run.to_s
              end
            else
              'N/A'
            end
            
            # Determine status icon and color based on status content
            status_icon, status_color = get_status_icon_and_color(status)
            
            @seed_configuration = {
              status: status,
              status_icon: status_icon,
              status_color: status_color,
              ready_for_use: true,
              last_run_formatted: last_run_formatted,
              registry_entries: defined?(SeedRegistryEntry) && SeedRegistryEntry.table_exists? ? SeedRegistryEntry.count : 0
            }
          else
            @seed_configuration = {
              status: 'Database is not initialized or is currently being restored',
              status_icon: 'fa-exclamation-triangle',
              status_color: 'danger',
              ready_for_use: true,
              last_run_formatted: 'N/A',
              registry_entries: 0
            }
          end
        rescue => e
          Rails.logger.error "Error fetching seed configuration: #{e.message}"
          @seed_configuration = {
            status: 'Error reading seed configuration',
            status_icon: 'fa-exclamation-triangle',
            status_color: 'danger',
            ready_for_use: true,
            last_run_formatted: 'N/A',
            registry_entries: 0
          }
        end
      elsif defined?(SeedRegistryEntry) && SeedRegistryEntry.table_exists?
        registry_entries = SeedRegistryEntry.count
        @seed_configuration = {
          status: 'Ready for YAML operations',
          status_icon: 'fa-check',
          status_color: 'success',
          ready_for_use: true,
          last_run_formatted: 'N/A',
          registry_entries: registry_entries
        }
      else
        @seed_configuration = {
          status: 'YASS ready (no seed registry found)',
          status_icon: 'fa-check',
          status_color: 'success',
          ready_for_use: true,
          last_run_formatted: 'N/A',
          registry_entries: 0
        }
      end
    end

    def seed_configuration_table_exists?
      begin
        ActiveRecord::Base.connection.table_exists?('seed_configuration')
      rescue => e
        Rails.logger.error "Error checking if seed_configuration table exists: #{e.message}"
        false
      end
    end

    def get_status_icon_and_color(status)
      status_lower = status.downcase
      
      # Green for complete/success states
      if status_lower.include?('complete') || status_lower.include?('success') || status_lower.include?('restored successfully')
        return ['fa-check-circle', 'success']
      end
      
      # Red for error/failed states
      if status_lower.include?('error') || status_lower.include?('failed')
        return ['fa-exclamation-circle', 'danger']
      end
      
      # Yellow for in-progress/processing states
      if status_lower.include?('in_progress') || status_lower.include?('processing') || 
         status_lower.include?('seeding') || status_lower.include?('populating') || 
         status_lower.include?('removing') || status_lower.include?('truncating') || 
         status_lower.include?('updating') || status_lower.include?('queued')
        return ['fa-spinner', 'warning']
      end
      
      # Default to success for ready states
      return ['fa-check', 'success']
    end
  end
end