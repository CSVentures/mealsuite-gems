# frozen_string_literal: true

source 'https://rubygems.org'

# Development dependencies shared across all gems
gem 'rake', '~> 13.0'
gem 'rspec', '~> 3.0'
gem 'rspec-rails'
gem 'rubocop', '~> 1.21'  # Use consistent version with gems
gem 'rubocop-rails'
gem 'rubocop-rspec'

# Load all gemspecs for cross-gem dependencies
Dir.glob('gems/*/*.gemspec').each do |gemspec_path|
  gemspec path: File.dirname(gemspec_path)
end