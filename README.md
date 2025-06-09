# CloudStorm Ventures Internal Gems

This repository contains internal Ruby gems used across CloudStorm Ventures projects.

## Gems

- **[yass](gems/yass/)** - YAML Assisted Seed System for Rails applications

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/csventures/csventures-gems
   cd csventures-gems
   ```

2. Run the setup script:
   ```bash
   bin/setup
   ```

3. Run tests for all gems:
   ```bash
   bin/test
   ```

## Using Gems in Your Projects

### For Production (Gemfile):
```ruby
gem 'yass', git: 'https://github.com/csventures/csventures-gems', glob: 'gems/yass/*.gemspec'
```

### For Local Development (Gemfile):
```ruby
gem 'yass', path: '../csventures-gems/gems/yass'
```

## Adding a New Gem

1. Create a new directory under `gems/`:
   ```bash
   mkdir gems/your-gem-name
   cd gems/your-gem-name
   ```

2. Generate the gem structure:
   ```bash
   bundle gem your-gem-name --no-git
   ```

3. Follow the shared conventions in `docs/contributing.md`

## Development

- Each gem has its own `README.md`, `CHANGELOG.md`, and `gemspec`
- Shared tooling is in the root directory
- Use consistent versioning across gems
- All gems should have comprehensive test coverage

## Release Process

1. Update the gem's version in `lib/gem_name/version.rb`
2. Update `CHANGELOG.md` for the gem
3. Run tests: `bin/test gem_name`
4. Create a release: `bin/release gem_name`

## Directory Structure

```
csventures-gems/
├── gems/                     # Individual gem directories
│   └── yass/                 # YAML Assisted Seed System
├── shared/                   # Shared configuration and utilities
├── bin/                      # Development and release scripts
├── docs/                     # Documentation
└── .github/workflows/        # CI/CD configuration
```