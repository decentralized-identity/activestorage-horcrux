require 'coveralls'
Coveralls.wear!

require 'bundler/setup'
require 'rails/all'
require 'active_storage/service/horcrux_service'
require 'securerandom'

SERVICE_CONFIGURATIONS = begin
  erb = ERB.new(Pathname.new(File.expand_path("service/configurations.yml", __dir__)).read)
  configuration = YAML.load(erb.result) || {}
  configuration.deep_symbolize_keys
rescue Errno::ENOENT
  puts "Missing service configuration file in spec/service/configurations.yml"
  {}
end

class Model
    def key=(value)
      $my_blob_key = value
    end
    def key
      $my_blob_key
    end
    def update(params)
    end
    def save!
      self
    end
end

class BlobStub
    class << self
      class_attribute :service
      def key=(value)
        @key = value
      end
      def key
	@key ||= SecureRandom.base36(28)
      end
      def create_and_upload!(args)
        service.upload key, args[:io]
	self
      end
      def reload
        self
      end
      def find_by_key(key)
        Model.new
      end
    end
end

class FixedKeyGenerator
  def initialize
    @key = SecureRandom.base58(24)
  end
  def generate
    @key
  end
end

class UniqueKeyGenerator
  def initialize
  end
  def generate
    SecureRandom.base58(24)
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

module SecureRandom
  BASE36_ALPHABET = ("0".."9").to_a + ("a".."z").to_a

  # SecureRandom.base58 generates a random base58 string.
  #
  # The argument _n_ specifies the length of the random string to be generated.
  #
  # If _n_ is not specified or is +nil+, 16 is assumed. It may be larger in the future.
  #
  # The result may contain alphanumeric characters except 0, O, I and l.
  #
  #   p SecureRandom.base58 # => "4kUgL2pdQMSCQtjE"
  #   p SecureRandom.base58(24) # => "77TMHrHJFvFDwodq8w7Ev2m7"
  def self.base58(n = 16)
    SecureRandom.random_bytes(n).unpack("C*").map do |byte|
      idx = byte % 64
      idx = SecureRandom.random_number(58) if idx >= 58
      BASE58_ALPHABET[idx]
    end.join
  end

  # SecureRandom.base36 generates a random base36 string in lowercase.
  #
  # The argument _n_ specifies the length of the random string to be generated.
  #
  # If _n_ is not specified or is +nil+, 16 is assumed. It may be larger in the future.
  # This method can be used over +base58+ if a deterministic case key is necessary.
  #
  # The result will contain alphanumeric characters in lowercase.
  #
  #   p SecureRandom.base36 # => "4kugl2pdqmscqtje"
  #   p SecureRandom.base36(24) # => "77tmhrhjfvfdwodq8w7ev2m7"
  def self.base36(n = 16)
    SecureRandom.random_bytes(n).unpack("C*").map do |byte|
      idx = byte % 64
      idx = SecureRandom.random_number(36) if idx >= 36
      BASE36_ALPHABET[idx]
    end.join
  end
end
