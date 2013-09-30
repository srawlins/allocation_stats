# Copyright 2013 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require_relative File.join("spec_helper")

describe AllocationStats do
  it "should only track new objects" do
    existing_array = [1,2,3,4,5]

    stats = AllocationStats.new do
      new_array = [1,2,3,4,5]
    end

    stats.new_allocations.class.should be Array
    stats.new_allocations.size.should == 1
  end

  it "should only track new objects; Hash String count twice :(" do
    existing_array = [1,2,3,4,5]

    stats = AllocationStats.new do
      new_hash = {"foo" => "bar", "baz" => "quux"}
    end

    stats.new_allocations.size.should == 7
  end

  it "should only track new objects" do
    existing_array = [1,2,3,4,5]

    stats = AllocationStats.new do
      new_object = Object.new
      new_array  = []
      new_string = ""
    end

    stats.new_allocations.class.should be Array
    stats.new_allocations.size.should == 3
  end
end
