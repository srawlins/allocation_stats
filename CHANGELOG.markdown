v0.1.5

* Added: README is much more complete now.
* Added: `AllocationStats.trace_rspec` is documented better.
* Added: `AllocationStats.reace_rspec` now always burns once to prevent
  `#autoload` from allocating where unexpected.
* Fixed: typo in README; thanks @tjchambers

v0.1.4

* Added: Build status now tracked with Travis
* Fixed: Working... better? with new frozen String keys
* Fixed: alias order changed so that PWD is searched after GEMDIR and
  RUBYLIBDIR, in case of vendored bundler directory.
* Added: `at_least` method for the AllocationsProxy, tested and documented
* Added: `AllocationStats.trace_rspec` to trace an RSpec run, tested and
  moderately documented

v0.1.3

* Fixed: BasicObjects can be tracked; fixes #1
* Added: much more documentation: up to 83%
* Fixed: Working with new frozen String keys

v0.1.2

* Added: `homepage` in the gemspec
* Added: more documentation: up to 71% now

v0.1.1

* Fixed: `required_ruby_version` in the gemspec

v0.1.0

* A lot of stuff
