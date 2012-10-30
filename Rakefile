require 'rake'
require 'rake/testtask'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the caterpillar gem'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

def run_coverage(files)
  rm_f "coverage"
  rm_f "coverage.data"

  if files.empty?
    puts "No files were specified for testing"
    return
  end

  files = files.join(" ")

  if RUBY_PLATFORM =~ /darwin/
    exclude = '--exclude "gems/*" --exclude "Library/Frameworks/*"'
  elsif RUBY_PLATFORM =~ /java/
    exclude = '--exclude "rubygems/*,jruby/*,parser*,gemspec*,_DELEGATION*,__FORWARDABLE__,erb,eval*,recognize_optimized*,yaml,yaml/*,fcntl"'
  else
    exclude = '--exclude "rubygems/*"'
  end

  rcov_bin = RUBY_PLATFORM =~ /java/ ? "jruby -S bundle exec rcov" : "bundle exec rcov"
  rcov = "#{rcov_bin} --rails -Ilib:test --sort coverage --text-report #{exclude}"
  puts
  puts
  puts "Running tests..."
  cmd = "#{rcov} #{files}"
  puts cmd
  sh cmd
end

namespace :test do
  desc "Measures test coverage"
  task :coverage do
    run_coverage Dir["test/**/*_test.rb"]
  end
end
