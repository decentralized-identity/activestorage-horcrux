require 'coveralls'
Coveralls.wear!

require "bundler/setup"
require 'rails/all'
require "active_storage/service/horcrux_service"

SERVICE_CONFIGURATIONS = begin
  erb = ERB.new(Pathname.new(File.expand_path("service/configurations.yml", __dir__)).read)
  configuration = YAML.load(erb.result) || {}
  configuration.deep_symbolize_keys
rescue Errno::ENOENT
  puts "Missing service configuration file in spec/service/configurations.yml"
  {}
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
