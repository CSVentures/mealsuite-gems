# frozen_string_literal: true

source 'https://rubygems.org'

# Development dependencies shared across all gems
gem 'rake', '~> 13.0'
gem 'rspec', '~> 3.0'
gem 'rspec-rails'
gem 'rubocop', '~> 1.0'
gem 'rubocop-rails'
gem 'rubocop-rspec'

# Load all gem dependencies for development
Dir.glob('gems/*/Gemfile').each do |gemfile|
  eval_gemfile gemfile
end

# Load all gemspecs for cross-gem dependencies
Dir.glob('gems/*/*.gemspec').each do |gemspec_path|
  gemspec path: File.dirname(gemspec_path)
end