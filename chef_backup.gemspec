lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "chef_backup/version"

Gem::Specification.new do |spec|
  spec.name          = "chef_backup"
  spec.version       = ChefBackup::VERSION
  spec.authors       = ["Chef Software, Inc."]
  spec.email         = ["oss@chef.io"]
  spec.summary       = "A library to backup a Chef Server"
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/chef/chef_backup"
  spec.license       = "Apache-2.0"

  spec.files         = %w{LICENSE} + Dir.glob("lib/**/*")
  spec.require_paths = ["lib"]

  spec.add_dependency "mixlib-shellout", ">= 2.0", "< 4.0"
  spec.add_dependency "pastel"
  spec.add_dependency "tty-prompt", "~> 0.21"
  spec.add_dependency "chef-utils", ">= 16.5.54" # for ChefUtils::Dist constants
end
