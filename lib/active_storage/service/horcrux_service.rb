# frozen_string_literal: true

require 'tss'
require 'base64'
require 'active_support/core_ext/module/delegation'

# frozen_string_literal: true

module ActiveStorage
  class Service::HorcruxService < Service
    attr_reader :services, :shares, :threshold, :prefix

    def upload(key,io,checksum: nil, **options)
      data = io.tap(&:rewind).read
      base64Data = Base64.encode64(data)
      shards = TSS.split(secret: base64Data,threshold: @threshold,num_shares: @shares)
      i = 0
      main_key = ""
      servicesamples = []
      while i < shards.count
        if servicesamples.empty?
	  servicesamples = services[0..-1]
	end
        svc = servicesamples.sample
	shardkey = SecureRandom.base58(key.length)

	scblob = Class.new Blob
	scblob.service = svc[:service]
	iofile = Tempfile.new(shardkey,"/tmp")
	iofile.write(shards[i])
	iofile.rewind
	myblob = scblob.create_and_upload! io:iofile, filename: ""
	iofile.close
	iofile.unlink

	main_key = main_key + "#{myblob.reload.key},"
	servicesamples.delete(svc)
	i = i + 1
      end
      main_blob = Blob.find_by_key(key)
      main_blob.key = main_key
      main_blob.save!
    end

    def download(keys,&block)
      shardkeys = keys.split(',')
      shards = []
      i = 0
      while i < shardkeys.count
        j = 0
	while j < services.count
	  begin
            if services[j][:service].exist?(shardkeys[i])
	      shard = services[j][:service].download(shardkeys[i])
	      shards << shard
	      break
	    end
	    j = j + 1
	  rescue NotImplementedError
	    begin
	      shard = services[j][:service].download(shardkeys[i]).to_s
	      if shard.match(/^invalid/)
	        j = j + 1
	      else
	        shards << shard
		break
	      end
	    rescue RestClient::BadRequest
	      j = j + 1
	    end
	  end
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

    def delete(keys)
      shardkeys = keys.split(',')
      shards = []
      i = 0
      while i < shardkeys.count
        j = 0
	while j < services.count
          if services[j][:service].exist?(shardkeys[i])
	    services[j][:service].delete(shardkeys[i])
	  end
	  j = j + 1
	end
	i = i + 1
      end
    end

    # Stitch together from named services.
    def self.build(services:, shares:, threshold:, prefix:, configurator:, **options) #:nodoc:
      new \
        shares: shares,
	threshold: threshold,
	prefix: prefix,
        services: services.collect { |name| { :name => name, :service => configurator.build(name) } }
    end

    def initialize(shares:,threshold:,prefix:,services:)
      @shares, @threshold, @prefix, @services = shares, threshold, prefix, services
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
          if services[j][:service].exist?(localKeys[i])
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
