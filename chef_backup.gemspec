# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chef_backup/version'

Gem::Specification.new do |spec|
  spec.name          = 'chef_backup'
  spec.version       = ChefBackup::VERSION
  spec.authors       = ['Chef Software, Inc.']
  spec.email         = ['oss@chef.io']
  spec.summary       = 'A library to backup a Chef Server'
  spec.description   = spec.summary
  spec.homepage      = 'https://github.com/chef/chef_backup'
  spec.license       = 'Apache-2.0'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(/^bin/) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features)/)
  spec.require_paths = ['lib']

  spec.add_dependency "mixlib-shellout", ">= 2.0", "< 4.0"
  spec.add_dependency "highline", "~> 1.6", ">= 1.6.9"

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rainbow', '< 2.2.0'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'guard-rspec'
  spec.add_development_dependency 'pry-rescue'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
end
