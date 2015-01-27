# ChefBackup
[![Build Status](https://travis-ci.org/ryancragun/chef_backup.svg?branch=master)](https://travis-ci.org/ryancragun/chef_backup)

A gem that backs up and restores Chef servers.

## Installation

Add this line to your application's Gemfile:

    gem 'chef_backup'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install chef_backup

## Usage

```shell
chef-server-ctl backup
chef-server-ctl restore some_backup.tgz
```

## Contributing

1. Fork it ( https://github.com/ryancragun/chef_backup/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
