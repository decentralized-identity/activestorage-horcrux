lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_storage/service/version'

Gem::Specification.new do |spec|
  spec.name          = "activestorage-horcrux"
  spec.version       = ActiveStorage::HorcruxService::VERSION
  spec.authors       = ["John Callahan"]
  spec.email         = ["jcallahan@acm.org"]

  spec.summary       = 'The Horcrux Protocol as an Active Storage service'
  spec.description   = 'Splits uploads using Shamir Secret Sharing across one or more other Active Storage services'
  spec.homepage      = "https://github.com/johncallahan/activestorage-horcrux"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.17.3"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "coveralls", "~> 0.8.22"
  spec.add_development_dependency "rails", "~> 5.2"
  spec.add_development_dependency "tss", "~> 0.4.0"
end
