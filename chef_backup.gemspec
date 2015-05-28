# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chef_backup/version'

Gem::Specification.new do |spec|
  spec.name          = 'chef_backup'
  spec.version       = ChefBackup::VERSION
  spec.authors       = ['Ryan Cragun']
  spec.email         = ['me@ryan.ec']
  spec.summary       = 'A library to backup a Chef Server'
  spec.description   = spec.summary
  spec.homepage      = 'https://github.com/chef/chef_backup'
  spec.license       = 'Apachev2'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(/^bin/) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features)/)
  spec.require_paths = ['lib']

  spec.add_dependency 'di-ruby-lvm'
  spec.add_dependency 'mixlib-shellout'
  spec.add_dependency 'highline'
  spec.add_dependency 'chef'

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'guard-rspec'
  spec.add_development_dependency 'pry-rescue'
  spec.add_development_dependency 'rubocop', '>= 0.28'
  spec.add_development_dependency 'simplecov'
end
