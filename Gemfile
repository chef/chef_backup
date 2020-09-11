source "https://rubygems.org"

# Specify your gem's dependencies in ec_backup.gemspec
gemspec

group :debug do
  gem "pry"
  gem "pry-rescue"
  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.6")
    gem "pry-stack_explorer", "~> 0.4.11"
  else
    gem "pry-stack_explorer"
  end
end

group :test do
  gem "chefstyle"
  gem "rake"
  gem "rspec", "~> 3.0"
  gem "simplecov"
end

group :docs do
  gem "github-markup"
  gem "redcarpet"
  gem "yard"
end
