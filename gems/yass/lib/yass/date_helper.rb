# frozen_string_literal: true

require 'date'

module Yass
  # DateHelper provides cross-Ruby compatibility for date operations
  # Works with both Rails and standalone Ruby environments
  module DateHelper
    class << self
      # Get current date - works with Rails or plain Ruby
      def current_date
        if defined?(Date.current)
          Date.current
        else
          Date.today
        end
      end

      # Get the next occurrence of a specific weekday
      def next_occurring(weekday)
        today = current_date
        days_until_weekday = (weekday_number(weekday) - today.wday) % 7
        days_until_weekday = 7 if days_until_weekday == 0 # If today is the target day, get next week's
        today + days_until_weekday
      end

      # Get the beginning of the current week (Monday)
      def beginning_of_week(start_day = :monday)
        today = current_date
        start_day_number = weekday_number(start_day)
        days_to_subtract = (today.wday - start_day_number) % 7
        today - days_to_subtract
      end

      # Add days to a date (works like Rails' day/days extension)
      def add_days(date, num_days)
        date + num_days
      end

      # Add weeks to a date
      def add_weeks(date, num_weeks)
        date + (num_weeks * 7)
      end

      # Add months to a date
      def add_months(date, num_months)
        if date.respond_to?(:next_month)
          # Rails way
          result = date
          num_months.times { result = result.next_month }
          result
        else
          # Plain Ruby way
          new_month = date.month + num_months
          new_year = date.year + (new_month - 1) / 12
          new_month = ((new_month - 1) % 12) + 1
          
          # Handle day overflow (e.g., Jan 31 + 1 month should be Feb 28/29)
          max_day = Date.new(new_year, new_month, -1).day
          new_day = [date.day, max_day].min
          
          Date.new(new_year, new_month, new_day)
        end
      end

      # Get beginning of month
      def beginning_of_month(date)
        Date.new(date.year, date.month, 1)
      end

      private

      # Convert weekday symbol to number (Sunday = 0, Monday = 1, etc.)
      def weekday_number(weekday)
        case weekday
        when :sunday then 0
        when :monday then 1
        when :tuesday then 2
        when :wednesday then 3
        when :thursday then 4
        when :friday then 5
        when :saturday then 6
        else
          raise ArgumentError, "Invalid weekday: #{weekday}"
        end
      end
    end
  end
end