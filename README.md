[![Build Status](https://travis-ci.org/johncallahan/activestorage-horcrux.svg?branch=master)](https://travis-ci.org/johncallahan/activestorage-horcrux)

An ActiveStorage gem that uploads across one or more other
ActiveStorage services using Shamir Secret Sharing (via the [tss-rb
gem](https://github.com/grempe/tss-rb)).  Use it in your storage.yml
file.  It is not a mirror, but can be named as a storage service.

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
  services: [ disk1, disk2 ]
```

Configuration elements:

* service: name of the service
* shares: specified the number of shares split across services.
* threshold: specifies the _minimum_ number of shares are needed to
reconstruct the contents.
* services: one or more other ActiveStorage services in storage.yml

Instead of a single key, an array of keys is passed to the upload
function.  The array of keys is not persisted and can be shown to the
user for subsequent downloads.
