# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'rubocop/rake_task'

desc 'Run tests for all gems'
task :test do
  Dir.glob('gems/*').each do |gem_dir|
    next unless File.directory?(gem_dir)
    
    gem_name = File.basename(gem_dir)
    puts "\n=== Testing #{gem_name} ==="
    
    Dir.chdir(gem_dir) do
      system('bundle exec rspec') || abort("Tests failed for #{gem_name}")
    end
  end
end

desc 'Run RuboCop for all gems'
task :rubocop do
  Dir.glob('gems/*').each do |gem_dir|
    next unless File.directory?(gem_dir)
    
    gem_name = File.basename(gem_dir)
    puts "\n=== RuboCop #{gem_name} ==="
    
    Dir.chdir(gem_dir) do
      system('bundle exec rubocop') || abort("RuboCop failed for #{gem_name}")
    end
  end
end

desc 'Install dependencies for all gems'
task :bundle do
  puts "=== Installing root dependencies ==="
  system('bundle install') || abort("Bundle install failed for root")
  
  Dir.glob('gems/*').each do |gem_dir|
    next unless File.directory?(gem_dir)
    
    gem_name = File.basename(gem_dir)
    puts "\n=== Installing dependencies for #{gem_name} ==="
    
    Dir.chdir(gem_dir) do
      system('bundle install') || abort("Bundle install failed for #{gem_name}")
    end
  end
end

desc 'Build all gems'
task :build do
  Dir.glob('gems/*').each do |gem_dir|
    next unless File.directory?(gem_dir)
    
    gem_name = File.basename(gem_dir)
    puts "\n=== Building #{gem_name} ==="
    
    Dir.chdir(gem_dir) do
      system('gem build *.gemspec') || abort("Build failed for #{gem_name}")
    end
  end
end

desc 'Clean built gems'
task :clean do
  Dir.glob('gems/*/*.gem').each do |gem_file|
    puts "Removing #{gem_file}"
    File.delete(gem_file)
  end
end

# Default task
task default: [:bundle, :test, :rubocop]