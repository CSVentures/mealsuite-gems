# frozen_string_literal: true

# Shared RSpec configuration for all gems
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  # Use the expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Random order
  config.order = :random
  Kernel.srand config.seed

  # Show the slowest examples
  config.profile_examples = 10

  # Run specs in random order to surface order dependencies
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option
  Kernel.srand config.seed

  # Print the test names as they run
  config.formatter = :documentation

  # Shared helper methods for all gems
  config.include Module.new {
    def with_temporary_file(content = '', extension = '.yml')
      require 'tempfile'
      file = Tempfile.new(['test', extension])
      file.write(content)
      file.close
      yield file.path
    ensure
      file&.unlink
    end

    def capture_stdout
      old_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  }
end