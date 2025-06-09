# frozen_string_literal: true

module Yass
  # Custom exception for YAML seed parsing errors with user-friendly messages
  class ParsingError < StandardError
    attr_reader :file_path, :error_type, :suggestions, :line_number, :column_number

    def initialize(message, file_path: nil, error_type: :general, suggestions: [], line_number: nil, column_number: nil)
      @file_path = file_path
      @error_type = error_type
      @suggestions = suggestions
      @line_number = line_number
      @column_number = column_number
      super(message)
    end

    def user_friendly_message
      msg = "❌ YAML Seed File Error\n\n"
      msg += "📄 File: #{File.basename(@file_path)}\n" if @file_path

      # Add line/column information if available
      if @line_number
        location = "📍 Location: Line #{@line_number}"
        location += ", Column #{@column_number}" if @column_number
        msg += "#{location}\n"
      end

      msg += "🔍 Problem: #{message}\n"

      if @suggestions.any?
        msg += "\n💡 How to fix this:\n"
        @suggestions.each_with_index do |suggestion, index|
          msg += "   #{index + 1}. #{suggestion}\n"
        end
      end

      msg
    end
  end
end
