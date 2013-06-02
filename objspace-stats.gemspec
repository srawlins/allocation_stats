Gem::Specification.new do |spec|
  spec.name          = "objspace-stats"
  spec.version       = "0.1.0"
  spec.authors       = ["Sam Rawlins"]
  spec.email         = ["sam.rawlins@gmail.com"]
  spec.summary       = "Tooling for tracing object allocations in Ruby 2.1"
  spec.description   = "Tooling for tracing object allocations in Ruby 2.1"

  spec.files         = `git ls-files`.split("\n")
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec"
end
