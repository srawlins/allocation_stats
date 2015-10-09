# Copyright 2014 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require_relative File.join("spec_helper")

describe AllocationStats do
  it "traces everything if TRACE_PROCESS_ALLOCATIONS env var is set" do
    IO.popen({"TRACE_PROCESS_ALLOCATIONS" => "1"}, "ruby -r ./lib/allocation_stats -e 'puts 0'") do |io|
      out = io.read
      expect(out).to match("Object Allocation Report")
    end
  end

  it "only tracks new objects" do
    existing_array = [1,2,3,4,5]

    stats = AllocationStats.trace do
      new_array = [1,2,3,4,5]
    end

    expect(stats.new_allocations.class).to be Array
    expect(stats.new_allocations.size).to eq 1
  end

  it "only tracks new objects, non-block mode" do
    existing_array = [1,2,3,4,5]

    stats = AllocationStats.trace
    new_array = [1,2,3,4,5]
    stats.stop

    expect(stats.new_allocations.class).to be Array
    expect(stats.new_allocations.size).to eq 1
  end

  it "only tracks new objects; String keys in Hashes are frozen" do
    existing_array = [1,2,3,4,5]

    stats = AllocationStats.trace do
      new_hash = {"foo" => "bar", "baz" => "quux"}
    end

    expect(stats.new_allocations.size).to eq 3
  end

  it "only tracks new objects, using instance method" do
    existing_array = [1,2,3,4,5]

    stats = AllocationStats.new

    stats.trace do
      new_object = Object.new
      new_array  = [4]
      new_string = "yarn"
    end

    expect(stats.new_allocations.class).to be Array
    expect(stats.new_allocations.size).to eq 3
  end

  it "only tracks new objects" do
    existing_array = [1,2,3,4,5]

    my_instance = MyClass.new

    stats = AllocationStats.new(burn: 3).trace do
      # this method instantiates 2**(n-1) Strings on the n'th call
      my_instance.memoizing_method
    end

    expect(stats.new_allocations.class).to be Array
    expect(stats.new_allocations.size).to eq 8
  end
end
