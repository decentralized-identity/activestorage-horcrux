[![Build Status](https://travis-ci.org/johncallahan/activestorage-horcrux.svg?branch=master)](https://travis-ci.org/johncallahan/activestorage-horcrux)

An ActiveStorage service option that uploads shares *across* one or
more other storage services using Shamir Secret Sharing (via the
[tss-rb gem](https://github.com/grempe/tss-rb)).  Use it in your
storage.yml file.  It is not a mirror, but can be named as a storage
service.

```ruby
# in storage.yml
disk1: 
  service: Disk
  root: "tmp/disk1"

disk2:
  service: Disk
  root: "tmp/disk2"

horcrux:
  service: Horcrux
  shares: 5
  threshold: 3
  prefix: true
  services: [ disk1, disk2 ]
```

# Configuration elements:

* service: name of the service
* shares: (integer) specified the number of shares split across services.
* threshold: (integer) specifies the _minimum_ number of shares are needed to reconstruct the contents.
* prefix: (boolean) prefix the key with the name of the service
* services: one or more other ActiveStorage services in storage.yml

After upload, the blob key is replaced with a comma-separated list of
keys for each shard.  You can retrieve the blob key(s) and then
replace it to hide the share keys (but remember to save them
someplace!).  Later, you can change the key(s) back again and download
the attachment shares (using at least threshold number of keys).

# Demo

Compatible with the [lockbox gem](https://github.com/ankane/lockbox).  See this [demo example](https://github.com/johncallahan/activestorage-horcrux-example).

# Testing

```shell
% rspec
```

# Development

Bump the version in lib/active_storage/service/version.rb and then

```shell
% bundle
% gem build activestorage-horcrux
% gem push activestorage-horcrux-0.0.x.gem
```

# To-do/Issues

* using Tempfile for passing back keys (yuck)
* size limitations (by the tss-rb gem)
* intercept and convert TSS errors to gem-specific errors
