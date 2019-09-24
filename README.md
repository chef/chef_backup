# ChefBackup
[![Build status](https://badge.buildkite.com/3006bd14f3d0d2281c9e323b9e33adb2a9373e6a319a5e6f13.svg?branch=master)](https://buildkite.com/chef-oss/chef-chef-backup-master-verify)
[![Gem Version](https://badge.fury.io/rb/chef_backup.svg)](http://badge.fury.io/rb/chef_backup)

A gem that backs up and restores Chef Infra Servers.  Used as the backend for
`chef-server-ctl backup` and `chef-server-ctl restore`

## Usage

```shell
chef-server-ctl backup
chef-server-ctl restore some_backup.tgz
```

## Contributing

1. Fork it ( https://github.com/chef/chef_backup/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
