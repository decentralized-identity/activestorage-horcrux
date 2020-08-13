# frozen_string_literal: true

require 'tss'
require 'base64'
require "active_support/core_ext/module/delegation"

# frozen_string_literal: true

module ActiveStorage
  class Service::HorcruxService < Service
    attr_reader :services, :shares, :threshold

    def upload(key,io,checksum: nil, **options)
      data = io.tap(&:rewind).read
      base64Data = Base64.encode64(data)
      shards = TSS.split(secret: base64Data,threshold: @threshold,num_shares: @shares)
      i = 0
      servicesamples = []
      file = Tempfile.new(key,"/tmp")
      while i < shards.count
        if servicesamples.empty?
	  servicesamples = services[0..-1]
	end
        svc = servicesamples.sample
	shardkey = SecureRandom.base58(key.length)
        svc.upload shardkey, StringIO.new(shards[i]), checksum: nil, **options
	file.write("#{shardkey},")
	servicesamples.delete(svc)
	i = i + 1
      end
      file.close
    end

    def download(keys,&block)
      shardkeys = keys.split(',')
      shards = []
      i = 0
      while i < shardkeys.count
        j = 0
	while j < services.count
          if services[j].exist?(shardkeys[i])
	    shards << services[j].download(shardkeys[i])
	  end
	  j = j + 1
	end
	i = i + 1
      end
      secret = TSS.combine(shares: shards)
      if block_given?
        yield Base64.decode64(secret[:secret])
      else
        return Base64.decode64(secret[:secret])
      end
    end

    def download_chunk(keys, range)
      raise ActiveStorage::UnpreviewableError, "Horcrux does not implement ranged download yet"
    end

    def delete(*args)
      perform_across_services(:delete, *args)
    end

    # Stitch together from named services.
    def self.build(services:, shares:, threshold:, configurator:, **options) #:nodoc:
      new \
        shares: shares,
	threshold: threshold,
        services: services.collect { |name| configurator.build name }
    end

    def initialize(shares:,threshold:,services:)
      @shares, @threshold, @services = shares, threshold, services
    end

    def delete_prefixed(*args)
      raise ActiveStorage::UnpreviewableError, "Horcrux does not implement delete by prefix yet"
    end

    def exist?(keys)
      localKeys = keys.split(',')
      i = 0
      while i < localKeys.count
        j = 0
	while j < services.count
          if services[j].exist?(localKeys[i])
	    return true
	  end
	  j = j + 1
	end
	i = i + 1
      end
      return false
    end

    def url(*args)
      raise ActiveStorage::UnpreviewableError, "Horcrux does not implement url yet"
    end

    def path_for(*args)
      raise ActiveStorage::UnpreviewableError, "Horcrux does not implement path_for yet"
    end

    private

    def each_service(&block)
      [ *services ].each(&block)
    end

    def perform_across_services(method, *args)
      # FIXME: Convert to be threaded
      each_service.collect do |service|
        service.public_send method, *args
      end
    end

  end
end
