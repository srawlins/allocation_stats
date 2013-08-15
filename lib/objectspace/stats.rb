# Copyright 2013 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require "objspace"
require_relative "stats/allocation"
require_relative "stats/allocations_proxy"

require "rubygems"

class ObjectSpace::Stats
  Rubylibdir = RbConfig::CONFIG["rubylibdir"]
  GemDir     = Gem.dir
  attr_accessor :gc_profiler_report, :new_allocations

  def initialize
    GC.start
    GC.disable

    @existing_object_ids = {}

    ObjectSpace.each_object.to_a.each do |object|
      @existing_object_ids[object.object_id / 1000] ||= []
      @existing_object_ids[object.object_id / 1000] << object.object_id
    end

    ObjectSpace.trace_object_allocations do
      yield if block_given?

      # not weak references
      @new_allocations = []
      ObjectSpace.each_object.to_a.each do |object|
        next if ObjectSpace.allocation_sourcefile(object).nil?
        next if ObjectSpace.allocation_sourcefile(object) == __FILE__
        next if @existing_object_ids[object.object_id / 1000] &&
                @existing_object_ids[object.object_id / 1000].include?(object.object_id)

        @new_allocations << Allocation.new(object)
      end
    end

    profile_and_start_gc
  end

  def inspect
    @new_allocations.inspect
  end

  def allocations
    AllocationsProxy.new(@new_allocations)
  end

  def profile_and_start_gc
    GC::Profiler.enable
    GC.enable
    GC.start
    @gc_profiler_report = GC::Profiler.result
    GC::Profiler.disable
  end


  def group_by_multiple(ary, *args)
    ary.group_by do |el|
      if args.size == 1
        arg = args.first
        arg.to_s[0] == "@" ? el.instance_variable_get(arg) : el.object.send(arg)
      else
        args.map do |arg|
          arg.to_s[0] == "@" ? el.instance_variable_get(arg) : el.object.send(arg)
        end
      end
    end
  end
end
