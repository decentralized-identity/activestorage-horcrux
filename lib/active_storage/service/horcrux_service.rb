# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

# frozen_string_literal: true

module ActiveStorage
  class Service::HorcruxService < Service
    attr_reader :services

    def upload(keys,threshold,data)
      raise ActiveStorage::UnpreviewableError, "Horcrux upload cannot handle IO stream, only String" if !data.kind_of?(String)
      shares = TSS.split(secret: data,threshold: threshold,num_shares: keys.count)
      i = 0
      servicesamples = []
      while i < shares.count
        if servicesamples.empty?
	  servicesamples = services[0..-1]
	end
        svc = servicesamples.sample
        svc.upload(keys[i],StringIO.new(shares[i]))
	servicesamples.delete(svc)
	i = i + 1
      end
    end

    def download(keys,&block)
      shares = []
      i = 0
      while i < keys.count
        j = 0
	while j < services.count
          if services[j].exist?(keys[i])
	    shares << services[j].download(keys[i])
	  end
	  j = j + 1
	end
	i = i + 1
      end
      secret = TSS.combine(shares: shares)
      if block_given?
        yield secret[:secret]
      else
        return secret[:secret]
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
      new services: services.collect { |name| configurator.build name }
    end

    def initialize(services:)
      @services = services
    end

    def delete_prefixed(*args)
      raise ActiveStorage::UnpreviewableError, "Horcrux does not implement delete by prefix yet"
    end

    def exist?(keys)
      localKeys = keys.kind_of?(Array) ? keys : [keys]
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
