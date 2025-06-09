# YASS (YAML Assisted Seed System)

A flexible YAML seed data parser that integrates with FactoryBot and Rails applications to provide declarative test data creation with reference resolution, bulk operations, and persistent registry management.

## Features

- **FactoryBot Integration**: Direct factory creation with traits and attributes
- **Reference Resolution**: Use `@variables` and `registry.*` lookups 
- **Ruby Code Execution**: Execute Ruby code blocks `[[Date.current + 1.week]]`
- **SeedHelper Methods**: Call existing seed helper methods
- **Persistent Registry**: Database-backed object registry with `SeedRegistryEntry` model
- **Error Handling**: User-friendly error messages with line numbers and suggestions
- **Rails Integration**: Generator for easy setup and migration creation
- **Web Integration**: HTTP endpoint support for uploading YAML files

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'yass'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install yass

## Setup

Run the generator to create the migration and initializer:

```bash
rails generate yass:install
rails db:migrate
```

This creates:
- Migration for `yass_seed_registry_entries` table
- Initializer at `config/initializers/yass.rb`
- Creates the YAML directory structure

## Configuration

```ruby
# config/initializers/yass.rb
Yass.configure do |config|
  config.logger = Rails.logger
  config.yaml_directory = Rails.root.join('db', 'seed', 'test_suites')
  config.seed_helpers_module = SeedHelpers # Your existing seed helpers module
  config.registry_model_class = Yass::SeedRegistryEntry # Default persistence model
end
```

## Basic Usage

### Loading Test Suites

```ruby
# Load a single test suite
objects = Yass::Loader.load_test_suite('basic_facility_test')

# Load multiple test suites
results = Yass::Loader.load_multiple(['users_test', 'accounts_test'])

# Load from YAML content string
yaml_content = File.read('my_seed.yml')
objects = Yass::Loader.load_from_content(yaml_content)
```

### Direct Parsing

```ruby
parser = Yass::Core.new(self) # Pass delegate context if needed
objects = parser.parse_file('path/to/seed.yml')
```

### Registry Management

```ruby
# Register objects manually
Yass::Registry.register('account.main', account_object)

# Get objects from registry
account = Yass::Registry.get('account.main')

# Check if key exists
if Yass::Registry.exists?('account.main')
  # Do something
end

# Clean up orphaned entries
Yass::Registry.clean_orphaned_entries!

# Clear all registry entries
Yass::Registry.clear_all!
```

## YAML Structure

### Basic Structure

```yaml
metadata:
  context: "Test Data"
  description: "Basic user and account setup"

data:
  accounts:
    - factory: account
      attributes:
        name: "Primary Account"
        active: true
      ref: "@primary_account"
      
  users:
    - factory: user
      traits: [:admin]
      attributes:
        name: "John Doe"
        email: "john@example.com"
        account: "@primary_account"  # Reference to previously created object
      ref: "@admin_user"
```

### Reference Types

#### Local References (@variables)
```yaml
accounts:
  - factory: account
    attributes:
      name: "Main Account"
    ref: "@main_account"
    
users:
  - factory: user
    attributes:
      account: "@main_account"  # Reference the account created above
      email: "@main_account.domain"  # Access account's domain attribute
```

#### Registry References (registry.*)
```yaml
users:
  - factory: user
    attributes:
      account: "registry.accounts.production_account"  # From persistent registry
      created_at: "registry.dates.next_monday"  # Built-in date helpers
```

#### Ruby Code Blocks
```yaml
events:
  - factory: event
    attributes:
      name: "Weekly Meeting"
      start_date: "[[Date.current + 1.week]]"  # Execute Ruby code
      description: "Meeting on [[Date.current.strftime('%A')]]"  # String interpolation
```

### Seed Helper Methods

```yaml
complex_data:
  - method: create_menu_with_items  # Call existing seed helper method
    arguments:
      account: "@primary_account"
      weeks: 4
      item_count: 10
    ref: "@complex_menu"
```

### Error Handling

YASS provides detailed error messages with:
- File path and line numbers
- Error type classification
- Helpful suggestions for fixes
- Context about available references

```
❌ YAML Seed File Error

📄 File: basic_test.yml
📍 Location: Line 15, Column 8
🔍 Problem: Reference '@unknown_account' not found in the current context.

💡 How to fix this:
   1. Check that you've defined the reference with 'ref: @unknown_account' in an earlier item
   2. Make sure the spelling matches exactly (references are case-sensitive)
   3. Verify the item with this reference is created before it's used
   4. Available references: @primary_account, @admin_user
```

## Integration with Rails

### SeedRegistryEntry Model

The gem includes a `Yass::SeedRegistryEntry` model that persists registry data:

```ruby
# Find all entries for a specific object type
entries = Yass::SeedRegistryEntry.for_object_class('Account')

# Search by key pattern
entries = Yass::SeedRegistryEntry.search_by_key('facility')

# Clean up orphaned entries
Yass::SeedRegistryEntry.clean_orphaned_entries!

# Group by context
contexts = Yass::SeedRegistryEntry.by_context
```

### Controller Integration

```ruby
class DataSeedingController < ApplicationController
  def load_yaml
    yaml_content = params[:yaml_content]
    
    begin
      objects = Yass::Loader.load_from_content(yaml_content)
      render json: { success: true, created_count: objects.count }
    rescue Yass::ParsingError => e
      render json: { 
        success: false, 
        error: e.user_friendly_message 
      }, status: 422
    end
  end
end
```

### Seed Files Integration

```ruby
# db/seeds.rb
if Rails.env.development? || Rails.env.test?
  # Load base reference data
  Yass::Loader.load_test_suite('base_accounts')
  
  # Load environment-specific data
  case Rails.env
  when 'development'
    Yass::Loader.load_multiple(['dev_users', 'sample_menus'])
  when 'test'
    # Test data loaded in individual test files
  end
end
```

## Database Schema

The migration creates the following table:

```sql
CREATE TABLE yass_seed_registry_entries (
  id BIGINT PRIMARY KEY,
  key VARCHAR NOT NULL,
  object_class VARCHAR NOT NULL,
  object_id INTEGER NOT NULL,
  description VARCHAR,
  context VARCHAR DEFAULT 'Reference Data',
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE UNIQUE INDEX index_yass_seed_registry_entries_on_key ON yass_seed_registry_entries (key);
CREATE INDEX index_yass_seed_registry_entries_on_object_class_and_object_id ON yass_seed_registry_entries (object_class, object_id);
CREATE INDEX index_yass_seed_registry_entries_on_context ON yass_seed_registry_entries (context);
```

## Date Helpers

YASS includes built-in date helpers accessible via `registry.dates.*`:

```yaml
# Basic dates
start_date: "registry.dates.today"
end_date: "registry.dates.tomorrow"
week_start: "registry.dates.next_week"

# Specific weekdays
meeting_date: "registry.dates.next_monday"
deadline: "registry.dates.next_friday"

# This week's days
today_meeting: "registry.dates.this_week_wednesday"

# Month dates
month_start: "registry.dates.first_of_this_month"
next_month: "registry.dates.first_of_next_month"
```

## Development

After checking out the repo, run:

```bash
bundle install
rake spec  # Run tests
```

To install this gem onto your local machine:

```bash
bundle exec rake install
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/your-org/yass.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).