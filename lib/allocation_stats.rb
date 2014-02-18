# Copyright 2014 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require "objspace"
require_relative "allocation_stats/core_ext/basic_object"
require_relative "allocation_stats/allocation"
require_relative "allocation_stats/allocations_proxy"
require_relative "allocation_stats/trace_rspec"

require "rubygems"

# Container for an aggregation of object allocation data. Pass a block to
# {#trace AllocationStats.new.trace}. Then use the AllocationStats object's public
# interface to dig into the data and discover useful information.
class AllocationStats
  # a convenience constant
  RUBYLIBDIR = RbConfig::CONFIG["rubylibdir"]

  # a convenience constant
  GEMDIR = Gem.dir

  # @!attribute [rw] burn
  # @return [Fixnum]
  # burn count for block tracing. Defaults to 0. When called with a block,
  # #trace will yield the block @burn-times before actually tracing the object
  # allocations. This offers the benefit of pre-memoizing objects, and loading
  # any required Ruby files before tracing.
  attr_accessor :burn

  attr_accessor :gc_profiler_report

  # @!attribute [r] new_allocations
  # @return [Array]
  # allocation data for all new objects that were allocated
  # during the {#initialize} block. It is better to use {#allocations}, which
  # returns an {AllocationsProxy}, which has a much more convenient,
  # domain-specific API for filtering, sorting, and grouping {Allocation}
  # objects, than this plain Array object.
  attr_reader :new_allocations

  def initialize(burn: 0)
    @burn = burn
    # Copying ridiculous workaround from:
    # https://github.com/ruby/ruby/commit/7170baa878ac0223f26fcf8c8bf25492415e6eaa
    Class.name
  end

  def self.trace(&block)
    allocation_stats = AllocationStats.new
    allocation_stats.trace(&block)
  end

  def trace(&block)
    if block_given?
      trace_block(&block)
    else
      start
    end
  end

  def trace_block
    @burn.times { yield }

    GC.start
    GC.disable

    @existing_object_ids = {}

    ObjectSpace.each_object.to_a.each do |object|
      @existing_object_ids[object.__id__ / 1000] ||= []
      @existing_object_ids[object.__id__ / 1000] << object.__id__
    end

    ObjectSpace.trace_object_allocations {
      yield
    }

    collect_new_allocations
    ObjectSpace.trace_object_allocations_clear
    profile_and_start_gc

    return self
  end

  # Begin tracing object allocations. Tracing must be stopped with
  # AllocationStats#stop. Garbage collection is disabled while tracing is
  # enabled.
  def start
    GC.start
    GC.disable

    @existing_object_ids = {}

    ObjectSpace.each_object.to_a.each do |object|
      @existing_object_ids[object.__id__ / 1000] ||= []
      @existing_object_ids[object.__id__ / 1000] << object.__id__
    end

    ObjectSpace.trace_object_allocations_start

    return self
  end

  def collect_new_allocations
    @new_allocations = []
    ObjectSpace.each_object.to_a.each do |object|
      next if ObjectSpace.allocation_sourcefile(object).nil?
      next if ObjectSpace.allocation_sourcefile(object) == __FILE__
      next if @existing_object_ids[object.__id__ / 1000] &&
              @existing_object_ids[object.__id__ / 1000].include?(object.__id__)

      @new_allocations << Allocation.new(object)
    end
  end

  # Stop tracing object allocations that was started with AllocationStats#start.
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
  $allocation_stats = AllocationStats.new.trace

  at_exit do
    $allocation_stats.stop
    puts "Object Allocation Report"
    puts "------------------------"
  end
end
