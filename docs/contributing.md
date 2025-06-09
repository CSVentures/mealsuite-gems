# Contributing to CloudStorm Ventures Gems

## Development Setup

1. Clone the repository and run setup:
   ```bash
   git clone https://github.com/csventures/csventures-gems
   cd csventures-gems
   bin/setup
   ```

## Creating a New Gem

1. Create the gem directory:
   ```bash
   mkdir gems/your-gem-name
   cd gems/your-gem-name
   ```

2. Generate the basic structure (or copy from yass as a template):
   ```bash
   bundle gem your-gem-name --no-git
   ```

3. Update the gemspec following our conventions:
   - Set appropriate dependencies
   - Use proper versioning
   - Include comprehensive description
   - Set license to 'Proprietary' for internal gems

## Conventions

### File Structure
Each gem should have:
- `lib/` - Main gem code
- `spec/` - RSpec tests
- `README.md` - Gem documentation
- `CHANGELOG.md` - Version history
- `Gemfile` - Development dependencies
- `*.gemspec` - Gem specification

### Code Style
- Follow the shared RuboCop configuration in `shared/rubocop.yml`
- Use frozen string literals: `# frozen_string_literal: true`
- Write comprehensive tests with good coverage
- Document public APIs

### Versioning
- Use semantic versioning (SemVer)
- Update `CHANGELOG.md` for each release
- Version should be in `lib/gem_name/version.rb`

### Testing
- Use RSpec for all tests
- Include shared configuration from `shared/rspec_config.rb`
- Aim for high test coverage
- Test against multiple Ruby versions in CI

## Development Workflow

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes and add tests

3. Run tests for your gem:
   ```bash
   bin/test your-gem-name
   ```

4. Run RuboCop:
   ```bash
   cd gems/your-gem-name
   bundle exec rubocop
   ```

5. Commit and push your changes

6. Create a pull request

## Release Process

1. Update the version in `lib/gem_name/version.rb`
2. Update `CHANGELOG.md` with the new version and changes
3. Run the release script:
   ```bash
   bin/release your-gem-name
   ```
4. The script will run tests, build the gem, and provide instructions for publishing

## Gem Dependencies

### Between Internal Gems
If one internal gem depends on another:
```ruby
# In gemspec
spec.add_dependency 'other-internal-gem', '~> 1.0'
```

### External Dependencies
- Pin to specific major versions where possible
- Use pessimistic version constraints (`~>`)
- Consider Ruby version compatibility

## CI/CD

The repository uses GitHub Actions for CI:
- Tests run on Ruby 2.7, 3.0, 3.1, and 3.2
- Only changed gems are tested on PRs (for efficiency)
- Full test suite runs on main branch pushes
- RuboCop linting runs for all gems

## Documentation

- Each gem should have a comprehensive README
- Include usage examples
- Document configuration options
- Keep CHANGELOG.md updated
- Add inline documentation for public APIs

## Questions?

If you have questions about contributing, please:
1. Check existing documentation
2. Look at the `yass` gem as an example
3. Ask in the team chat
4. Create an issue for clarification