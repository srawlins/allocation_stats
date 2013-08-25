# Copyright 2013 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require_relative "../lib/objectspace/stats"
require "yaml"
require "yajl"

if RbConfig::CONFIG["MAJOR"].to_i < 2 || RbConfig::CONFIG["MINOR"].to_i < 1
  warn "Error: ObjectStats requires Ruby 2.1 or greater"
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
end
