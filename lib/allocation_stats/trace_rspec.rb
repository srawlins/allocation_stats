# Copyright 2014 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

class AllocationStats
  def self.trace_rspec
    @top_sites = []

    if (!const_defined?(:RSpec))
      raise StandardError, "Cannot trace RSpec until RSpec is loaded"
    end

    ::RSpec.configure do |config|
      config.around(&TRACE_RSPEC_HOOK)
    end

    at_exit do
      puts AllocationStats.top_sites_text
    end
  end

  TRACE_RSPEC_HOOK = proc do |example|
     # TODO s/false/some config option/
     if true  # wrap loosely
       stats = AllocationStats.new(burn: 1).trace { example.run }
     else      # wrap tightly
       # Super hacky, but presumably more correct results?
       stats = AllocationStats.new(burn: 1)
       example_block = @example.instance_variable_get(:@example_block).clone

       @example.instance_variable_set(
         :@example_block,
         Proc.new do
           stats.trace { example_block.call }
         end
       )

       example.run
     end

     allocations = stats.allocations(alias_paths: true).
       not_from("rspec-core").not_from("rspec-expectations").not_from("rspec-mocks").
       group_by(:sourcefile, :sourceline, :class).
       sort_by_count

     AllocationStats.add_to_top_sites(allocations.all, @example.location)
  end

  # Read the sorted list of the top "sites", that is, top file/line/class
  # groups, encountered while tracing RSpec.
  #
  # @api private
  def self.top_sites
    @top_sites
  end

  # Write to the sorted list of the top "sites", that is, top file/line/class
  # groups, encountered while tracing RSpec.
  #
  # @api private
  def self.top_sites=(value)
    @top_sites = value
  end

  # Add a Hash of allocation groups (derived from an
  # `AllocationStats.allocations...group_by(...)`) to the top allocation sites
  # (file/line/class groups).
  #
  # @param [Hash] allocations
  # @param [String] location the RSpec spec location that was being executed
  #        when the allocations occurred
  # @param [Fixnum] limit size of the top sites Array
  def self.add_to_top_sites(allocations, location, limit = 10)
    if allocations.size > limit
      allocations = allocations.to_a[0...limit].to_h  # top 10 or so
    end

    # TODO: not a great algorithm so far... can instead:
    # * oly insert when an allocation won't be immediately dropped
    # * insert into correct position and pop rather than sort and slice
    allocations.each do |k,v|
      next if k[0] =~ /spec_helper\.rb$/

      if site = @top_sites.detect { |s| s[:key] == k }
        if lower_idx = site[:counts].index { |loc, count| count < v.size }
          site[:counts].insert(lower_idx, [location, v.size])
        else
          site[:counts] << [location, v.size]
        end
        site[:counts].pop if site[:counts].size > 3
      else
        @top_sites << { key: k, counts: [[location, v.size]] }
      end
    end

    @top_sites = @top_sites.sort_by! { |site|
      -site[:counts].map(&:last).max
    }[0...limit]
  end

  # Textual String representing the sorted list of the top allocation sites.
  # For each site, this String includes the number of allocations, the class,
  # the sourcefile, the sourceline, and the location of the RSpec spec.
  #
  # @api private
  def self.top_sites_text
    return "" if @top_sites.empty?

    result = "Top #{@top_sites.size} allocation sites:\n"
    @top_sites.each do |site|
      result << "  %s allocations at %s:%d\n" % [site[:key][2], site[:key][0], site[:key][1]]
      site[:counts].each do |location, count|
        result << "    %3d allocations during %s\n" % [count, location]
      end
    end

    result
  end
end
