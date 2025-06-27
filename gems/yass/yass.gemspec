# frozen_string_literal: true

require_relative 'lib/yass/version'

Gem::Specification.new do |spec|
  spec.name = 'yass'
  spec.version = Yass::VERSION
  spec.authors = ['CloudStorm Ventures']
  spec.email = ['andrew.s@mealsuite.com']

  spec.summary = 'YAML Assisted Seed System - A flexible YAML seed data parser for Rails applications'
  spec.description = 'YASS (YAML Assisted Seed System) is a flexible YAML seed data parser that integrates with FactoryBot and Rails applications to provide declarative test data creation with reference resolution, bulk operations, and persistent registry management.'
  spec.homepage = 'https://github.com/csventures/mealsuite-gems'
  spec.license = 'Proprietary'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    if Dir.exist?('.git')
      `git ls-files -z`.split("\x0").reject do |f|
        (File.expand_path(f) == __FILE__) ||
          f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
      end
    else
      Dir.glob('**/*').reject do |f|
        File.directory?(f) ||
          (File.expand_path(f) == __FILE__) ||
          f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile]) ||
          f.end_with?('.gem')
      end
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Dependencies
  spec.add_dependency 'factory_bot', '>= 4.0', '< 7.0'
  # Rails version should be inherited from the host application
  spec.add_dependency 'sass-rails', '>= 5.0', '< 6.0'

  # Development dependencies
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-rails'
end
