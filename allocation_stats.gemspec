# Copyright 2014 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

Gem::Specification.new do |spec|
  spec.name          = "allocation_stats"
  spec.version       = "0.1.4"
  spec.authors       = ["Sam Rawlins"]
  spec.email         = ["sam.rawlins@gmail.com"]
  spec.homepage      = "https://github.com/srawlins/allocation_stats"
  spec.license       = "Apache v2"
  spec.summary       = "Tooling for tracing object allocations in Ruby 2.1"
  spec.description   = "Tooling for tracing object allocations in Ruby 2.1"

  spec.files         = `git ls-files`.split("\n")
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec"

  # ">= 2.1.0" seems logical, but rubygems thought that "2.1.0.dev.0" did not fit that bill.
  # "> 2.0.0" was my next guess, but apparently "2.0.0.247" _does_ fit that bill.
  spec.required_ruby_version = "> 2.0.99"
end
