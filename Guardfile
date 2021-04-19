# A sample Guardfile
# More info at https://github.com/guard/guard#readme

# Note: The cmd option is now required due to the increasing number of ways
#       rspec may be run, below are examples of the most common uses.
#  * bundler: 'bundle exec rspec'
#  * bundler binstubs: 'bin/rspec'
#  * spring: 'bin/rsspec' (This will use spring if running and you have
#                          installed the spring binstubs per the docs)
#  * zeus: 'zeus rspec' (requires the server to be started separetly)
#  * 'just' rspec: 'rspec'
guard :rspec, cmd: "bundle exec rspec -f doc --color", all_after_pass: true do
  watch(%r{^spec/.+/.+_spec\.rb$})
  watch(%r{^spec/.+/.+/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$}) { |m| "spec/unit/#{m[1]}_spec.rb" }
  watch(%r{^lib/chef_backup/(.+)\.rb$}) { |m| "spec/unit/#{m[1]}_spec.rb" }
  watch(%r{^lib/chef_backup/(.+)/(.+)\.rb$})  { |m| "spec/unit/#{m[1]}/#{m[2]}_spec.rb" }
  watch(%r{^lib/chef_backup/(.+)/(.+)/(.+)\.rb$}) { |m| "spec/unit/#{m[1]}/#{m[2]}/#{m[3]}_spec.rb" }
  watch("spec/spec_helper.rb") { "spec" }
end

notification :tmux
