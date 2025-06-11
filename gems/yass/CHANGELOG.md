# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-06-11

### Added
- Bulk creation functionality with template interpolation
- Template variable support using {{index}} syntax
- Mathematical expressions in templates (e.g., {{index / 3 + 1}})
- Deep hash copying for template processing
- Comprehensive error handling for bulk creation scenarios
- Full test coverage for bulk creation features

### Features
- Create multiple objects from a single template configuration
- Support for dynamic attribute generation based on item index
- Reference resolution within bulk creation templates
- Safe template expression evaluation with detailed error messages

## [0.1.0] - 2025-06-09

### Added
- YASS (YAML Assisted Seed System) gem structure and core functionality
- YAML seed parser with FactoryBot integration
- Reference resolution system (@variables and registry.* lookups)
- Ruby code execution in YAML files
- Comprehensive error handling with user-friendly messages
- Persistent registry with Yass::SeedRegistryEntry model
- Rails generator for easy setup (rails generate yass:install)
- Database migration for seed registry entries
- Built-in date helpers (registry.dates.today, registry.dates.next_monday, etc.)
- Seed helper method integration
- Configurable logging and directory settings
- In-memory and database-backed object registry options
- Test suite loader with validation
- Web integration support for HTTP endpoints

### Features
- Parse YAML files to create objects via FactoryBot
- Support for traits and attributes in factory definitions
- Local reference system using @variable_name syntax
- Registry reference system using registry.type.key syntax
- Ruby code blocks with [[code]] syntax
- Detailed error reporting with line numbers and suggestions
- Object registry with persistence and cleanup capabilities
- Rails integration with generator and initializer
- SeedRegistryEntry model with search and management features

## [0.1.0] - 2025-06-09

### Added
- Initial release as YASS (YAML Assisted Seed System)
- Core functionality extracted from internal YamlSeedParser
- Renamed and restructured with proper module namespacing
- Enhanced with persistent registry capabilities
- Complete Rails integration with generator support
- Basic test coverage and comprehensive documentation