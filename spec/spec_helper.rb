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

class NullObject
  private
  def method_missing(method, *args, &block)
    # ignore
  end
end
