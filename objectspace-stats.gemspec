# Copyright 2013 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

Gem::Specification.new do |spec|
  spec.name          = "objectspace-stats"
  spec.version       = "0.1.0"
  spec.authors       = ["Sam Rawlins"]
  spec.email         = ["sam.rawlins@gmail.com"]
  spec.license       = "Apache v2"
  spec.summary       = "Tooling for tracing object allocations in Ruby 2.1"
  spec.description   = "Tooling for tracing object allocations in Ruby 2.1"

  spec.files         = `git ls-files`.split("\n")
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec"
end
