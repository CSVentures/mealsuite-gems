# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yass::DateHelper do
  describe '.current_date' do
    it 'returns a Date object' do
      expect(described_class.current_date).to be_a(Date)
    end
  end

  describe '.add_days' do
    it 'adds the specified number of days to a date' do
      date = Date.new(2025, 6, 1)
      result = described_class.add_days(date, 5)
      expect(result).to eq(Date.new(2025, 6, 6))
    end
  end

  describe '.add_weeks' do
    it 'adds the specified number of weeks to a date' do
      date = Date.new(2025, 6, 1)
      result = described_class.add_weeks(date, 2)
      expect(result).to eq(Date.new(2025, 6, 15))
    end
  end

  describe '.next_occurring' do
    it 'returns the next occurrence of a weekday' do
      # Using a known Monday (2025-06-09)
      monday = Date.new(2025, 6, 9)
      
      # Mock current_date to return our test Monday
      allow(described_class).to receive(:current_date).and_return(monday)
      
      next_friday = described_class.next_occurring(:friday)
      expect(next_friday).to eq(Date.new(2025, 6, 13)) # Friday of the same week
      
      next_monday = described_class.next_occurring(:monday)
      expect(next_monday).to eq(Date.new(2025, 6, 16)) # Next Monday (not today)
    end
  end

  describe '.beginning_of_week' do
    it 'returns the beginning of the week (Monday by default)' do
      # Using a known Wednesday (2025-06-11)
      wednesday = Date.new(2025, 6, 11)
      
      # Mock current_date to return our test Wednesday
      allow(described_class).to receive(:current_date).and_return(wednesday)
      
      monday = described_class.beginning_of_week(:monday)
      expect(monday).to eq(Date.new(2025, 6, 9)) # Monday of the same week
    end
  end

  describe '.add_months' do
    it 'adds months correctly' do
      date = Date.new(2025, 1, 15)
      result = described_class.add_months(date, 2)
      expect(result).to eq(Date.new(2025, 3, 15))
    end

    it 'handles year rollover' do
      date = Date.new(2025, 11, 15)
      result = described_class.add_months(date, 3)
      expect(result).to eq(Date.new(2026, 2, 15))
    end

    it 'handles day overflow gracefully' do
      date = Date.new(2025, 1, 31)
      result = described_class.add_months(date, 1)
      expect(result).to eq(Date.new(2025, 2, 28)) # February only has 28 days
    end
  end

  describe '.beginning_of_month' do
    it 'returns the first day of the month' do
      date = Date.new(2025, 6, 15)
      result = described_class.beginning_of_month(date)
      expect(result).to eq(Date.new(2025, 6, 1))
    end
  end
end