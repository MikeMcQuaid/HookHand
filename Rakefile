require "rake/testtask"

Rake::TestTask.new {|t| t.test_files = ["test/test.rb"] }

task :default => :test

task :coverage do
  ENV["COVERAGE"] = "1"
  Rake::Task["test"].execute
end
