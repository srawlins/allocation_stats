# Copyright 2014 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require "simplecov"
SimpleCov.start

require_relative "../lib/allocation_stats"
require "yaml"
require "yajl"
require "pry"

if RbConfig::CONFIG["MAJOR"].to_i < 2 || RbConfig::CONFIG["MINOR"].to_i < 1
  warn "Error: AllocationStats requires Ruby 2.1 or greater"
  exit 1
end

def allocate_a_string_from_spec_helper
  return "a string from spec_helper"
end

class MyClass
  def my_method
    @new_hash = {0 => "foo", 1 => "bar"}
  end

  MY_METHOD_BODY_LINE = __LINE__ - 3

  # This method allocates a different number of objects each call:
  # 1st call: 1x Array, 1x String
  # 2nd call;           2x Strings
  # 3rd call;           4x Strings
  # 4th call;           8x Strings
  def memoizing_method
    @c ||= []

    (@c.size + 1).times { @c << "string" }
  end
end

# from rspec-core 2.14.7's spec_helper.rb: https://github.com/rspec/rspec-core/blob/v2.14.7/spec/spec_helper.rb#L31
class NullObject
  private
  def method_missing(method, *args, &block)
    # ignore
  end
end

# from rspec-core 2.14.7's spec_helper.rb: https://github.com/rspec/rspec-core/blob/v2.14.7/spec/spec_helper.rb#L38
#
# THIS WILL NEED TO BE ENTIRELY REPLACED WHEN BUMPING TO RSPEC 3
module Sandboxing
  def self.sandboxed(&block)
    @orig_config = RSpec.configuration
    @orig_world  = RSpec.world
    new_config = RSpec::Core::Configuration.new
    new_world  = RSpec::Core::World.new(new_config)
    RSpec.configuration = new_config
    RSpec.world = new_world
    object = Object.new
    object.extend(RSpec::Core::SharedExampleGroup)

    (class << RSpec::Core::ExampleGroup; self; end).class_eval do
      alias_method :orig_run, :run
      def run(reporter=nil)
        orig_run(reporter || NullObject.new)
      end
    end

    RSpec::Core::SandboxedMockSpace.sandboxed do
      object.instance_eval(&block)
    end
  ensure
    (class << RSpec::Core::ExampleGroup; self; end).class_eval do
      remove_method :run
      alias_method :run, :orig_run
      remove_method :orig_run
    end

    RSpec.configuration = @orig_config
    RSpec.world = @orig_world
  end
end

############
# from https://raw.github.com/rspec/rspec-core/v2.14.7/spec/support/sandboxed_mock_space.rb
#
# THIS WILL NEED TO BE ENTIRELY DELETED WHEN BUMPING TO RSPEC 3
############
require 'rspec/mocks'

module RSpec
  module Core
    # Because rspec-core dog-foods itself, rspec-core's spec suite has
    # examples that define example groups and examples and run them. The
    # usual lifetime of an RSpec::Mocks::Proxy is for one example
    # (the proxy cache gets cleared between each example), but since the
    # specs in rspec-core's suite sometimes create test doubles and pass
    # them to examples a spec defines and runs, the test double's proxy
    # must live beyond the inner example: it must live for the scope
    # of wherever it got defined. Here we implement the necessary semantics
    # for rspec-core's specs:
    #
    # - #verify_all and #reset_all affect only mocks that were created
    #   within the current scope.
    # - Mock proxies live for the duration of the scope in which they are
    #   created.
    #
    # Thus, mock proxies created in an inner example live for only that
    # example, but mock proxies created in an outer example can be used
    # in an inner example but will only be reset/verified when the outer
    # example completes.
    class SandboxedMockSpace < ::RSpec::Mocks::Space
      def self.sandboxed
        orig_space = RSpec::Mocks.space
        RSpec::Mocks.space = RSpec::Core::SandboxedMockSpace.new

        RSpec::Core::Example.class_eval do
          alias_method :orig_run, :run
          def run(*args)
            RSpec::Mocks.space.sandboxed do
              orig_run(*args)
            end
          end
        end

        yield
      ensure
        RSpec::Core::Example.class_eval do
          remove_method :run
          alias_method :run, :orig_run
          remove_method :orig_run
        end

        RSpec::Mocks.space = orig_space
      end

      class Sandbox
        attr_reader :proxies

        def initialize
          @proxies = Set.new
        end

        def verify_all
          @proxies.each { |p| p.verify }
        end

        def reset_all
          @proxies.each { |p| p.reset }
        end
      end

      def initialize
        @sandbox_stack = []
        super
      end

      def sandboxed
        @sandbox_stack << Sandbox.new
        yield
      ensure
        @sandbox_stack.pop
      end

      def verify_all
        return super unless sandbox = @sandbox_stack.last
        sandbox.verify_all
      end

      def reset_all
        return super unless sandbox = @sandbox_stack.last
        sandbox.reset_all
      end

      def proxy_for(object)
        new_proxy = !proxies.has_key?(object.__id__)
        proxy = super

        if new_proxy && sandbox = @sandbox_stack.last
          sandbox.proxies << proxy
        end

        proxy
      end
    end
  end
end
