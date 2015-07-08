# ChefBackup
[![Build Status](https://travis-ci.org/chef/chef_backup.svg?branch=master)](https://travis-ci.org/chef/chef_backup)
[![Gem Version](https://badge.fury.io/rb/chef_backup.svg)](http://badge.fury.io/rb/chef_backup)

A gem that backs up and restores Chef servers.  Used as the backend for
`chef-server-ctl backup` and `chef-server-ctl restore`

## Usage

```shell
chef-server-ctl backup
chef-server-ctl restore some_backup.tgz
```

## Running on older server before Chef Server 12.1.0

As root:

```
/opt/opscode/embedded/bin/gem install --pre chef_server --no-ri --no-rdoc
/opt/opscode/embedded/bin/chef_backup
```

## Contributing

1. Fork it ( https://github.com/chef/chef_backup/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
