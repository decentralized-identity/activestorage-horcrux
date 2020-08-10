# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module ActiveStorage
  class Service::HorcruxService < Service
    attr_reader :services

    def upload(keys,threshold,data)
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

    def download(keys)
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
      return secret[:secret]
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
      perform_across_services(:delete_prefixed, *args)
    end

    def download_chunk(*args)
      services[0].download_chunk(*args)
    end

    def exist?(*args)
      services[0].exist?(*args)
    end

    def url(*args)
      services[0].url(*args)
    end

    def path_for(*args)
      services[0].path_for(*args)
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
