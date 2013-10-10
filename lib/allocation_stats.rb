# Copyright 2013 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require "objspace"
require_relative "allocation_stats/allocation"
require_relative "allocation_stats/allocations_proxy"

require "rubygems"

# Container for an aggregation of object allocation data. Pass a block to
# {#initialize AllocationStats.new()}. Then use the AllocationStats object's public
# interface to dig into the data and discover useful information.
class AllocationStats
  # a convenience constant
  Rubylibdir = RbConfig::CONFIG["rubylibdir"]

  # a convenience constant
  GemDir = Gem.dir

  attr_accessor :gc_profiler_report

  # @!attribute [r] new_allocations
  # @return [Array]
  # allocation data for all new objects that were allocated
  # during the {#initialize} block. It is better to use {#allocations}, which
  # returns an {AllocationsProxy}, which has a much more convenient,
  # domain-specific API for filtering, sorting, and grouping {Allocation}
  # objects, than this plain Array object.
  attr_reader :new_allocations

  def initialize
    GC.start
    GC.disable

    @existing_object_ids = {}

    ObjectSpace.each_object.to_a.each do |object|
      @existing_object_ids[object.object_id / 1000] ||= []
      @existing_object_ids[object.object_id / 1000] << object.object_id
    end

    if block_given?
      ObjectSpace.trace_object_allocations {
        yield
      }

      collect_new_allocations
      ObjectSpace.trace_object_allocations_clear

      profile_and_start_gc
    else
      ObjectSpace.trace_object_allocations_start
    end
  end

  def collect_new_allocations
    @new_allocations = []
    ObjectSpace.each_object.to_a.each do |object|
      next if ObjectSpace.allocation_sourcefile(object).nil?
      next if ObjectSpace.allocation_sourcefile(object) == __FILE__
      next if @existing_object_ids[object.object_id / 1000] &&
              @existing_object_ids[object.object_id / 1000].include?(object.object_id)

      @new_allocations << Allocation.new(object)
    end
  end

  def stop
    collect_new_allocations

    ObjectSpace.trace_object_allocations_stop
    ObjectSpace.trace_object_allocations_clear

    profile_and_start_gc
  end

  # Inspect @new_allocations, the canonical array of {Allocation} objects.
  def inspect
    @new_allocations.inspect
  end

  # Proxy for the @new_allocations array that allows for individual filtering,
  # sorting, and grouping of the Allocation objects.
  def allocations(alias_paths: false)
    AllocationsProxy.new(@new_allocations, alias_paths: alias_paths)
  end

  def profile_and_start_gc
    GC::Profiler.enable
    GC.enable
    GC.start
    @gc_profiler_report = GC::Profiler.result
    GC::Profiler.disable
  end
  private :profile_and_start_gc
end

if ENV["TRACE_PROCESS_ALLOCATIONS"]
  $allocation_stats = AllocationStats.new

  at_exit do
    $allocation_stats.stop
    puts "Object Allocation Report"
    puts "------------------------"
  end
end
