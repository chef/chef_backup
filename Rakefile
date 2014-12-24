#!/usr/bin/env rake

require 'rake'
require 'rspec'
require 'rspec/core'
require 'rspec/core/rake_task'
require 'bundler'
require 'bundler/gem_tasks'
require 'rubocop/rake_task'

desc 'Default task to run spec suite'
task default: %w(spec rubocop)

desc 'Run spec suite'
RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = FileList['spec/**/*_spec.rb']
end

desc 'Run RSpec with code coverage'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['spec'].execute
end

desc 'Run Rubocop style checks'
RuboCop::RakeTask.new do |cop|
  cop.fail_on_error = true
end

desc 'console'
task :console do
  require 'pry'
  require 'chef_backup'
  require 'json'
  f = File.expand_path('../spec/fixtures/chef-server-running.json', __FILE__)
  running_config = JSON.parse(File.read(f))
  @backup = ChefBackup::Backup.new(running_config, '/tmp/backup.tgz')
  ARGV.clear
  Pry.config.history.should_save = true
  Pry.config.history.should_load = true
  Pry.start
end
