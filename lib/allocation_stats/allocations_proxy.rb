# Copyright 2014 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

class AllocationStats
  # AllocationsProxy acts as a proxy for an array of Allocation objects. The
  # idea behind this class is merely to provide some domain-specific methods
  # for transforming (filtering, sorting, and grouping) allocation information.
  # This class uses the Command pattern heavily, in order to build and maintain
  # the list of transforms it will ultimately perform, before retrieving the
  # transformed collection of Allocations.
  #
  # Chaining
  # ========
  #
  # Use of the Command pattern and Procs allows for transform-chaining in any
  # order. Apply methods such as {#from} and {#group_by} to build the internal
  # list of transforms. The transforms will not be applied to the collection of
  # Allocations until a call to {#to_a} ({#all}) resolves them.
  #
  # Filtering Transforms
  # --------------------
  #
  # Methods that filter the collection of Allocations will add a transform to
  # an Array, `@wheres`. When the result set is finally retrieved, each where
  # is applied serially, so that `@wheres` represents a logical conjunction
  # (_"and"_) of of filtering transforms. Presently there is no way to _"or"_
  # filtering transforms together with a logical disjunction.
  #
  # Mapping Transforms
  # ------------------
  #
  # Grouping Transform
  # ------------------
  #
  # Only one method will allow a grouping transform: {#group_by}. Only one
  # grouping transform is allowed; subsequent calls to {#group_by} will only
  # replace the previous grouping transform.
  class AllocationsProxy

    # Instantiate an {AllocationsProxy} with an array of Allocations.
    # {AllocationProxy's} view of `pwd` is set at instantiation.
    #
    # @param [Array<Allocation>] allocations array of Allocation objects
    def initialize(allocations, alias_paths: false)
      @allocations = allocations
      @pwd = Dir.pwd
      @wheres = []
      @group_by = nil
      @mappers  = []
      @alias_paths = alias_paths
    end

    # Apply all transformations to the contained list of Allocations. This is
    # aliased as `:all`.
    def to_a
      results = @allocations

      @wheres.each do |where|
        results = where.call(results)
      end

      # First apply group_by
      results = @group_by.call(results) if @group_by

      # Apply each mapper
      @mappers.each do |mapper|
        results = mapper.call(results)
      end

      results
    end
    alias :all :to_a

    # If a value is passed in, @alias_paths will be set to this value, and the
    # AllocationStats object will be returned. If no value is passed in, this
    # will return the @alias_paths.
    def alias_paths(value = nil)
      # reader
      return @alias_paths if value.nil?

      # writer
      @alias_paths = value

      return self
    end

    # Sort allocation groups by the number of allocations in each group.
    def sort_by_size
      @mappers << Proc.new do |allocations|
        allocations.sort_by { |key, value| -value.size }
                   .inject({}) { |hash, pair| hash[pair[0]] = pair[1]; hash }
      end

      self
    end
    alias :sort_by_count :sort_by_size

    # Select allocation groups which have at least `count` allocations.
    #
    # @param [Fixnum] count the minimum number of Allocations for each group to
    # be selected.
    def at_least(count)
      @mappers << Proc.new do |allocations|
        allocations.delete_if { |key,value| value.size < count }
      end

      self
    end

    # Select allocations for which the {Allocation#sourcefile sourcefile}
    # includes `pattern`.
    #
    # `#from` can be called multiple times, adding to `@wheres`. See
    # documentation for {AllocationsProxy} for more information about chaining.
    #
    # @param [String] pattern the partial file path to match against, in the
    #   {Allocation#sourcefile Allocation's sourcefile}.
    def from(pattern)
      @wheres << Proc.new do |allocations|
        allocations.select { |allocation| allocation.sourcefile[pattern] }
      end

      self
    end

    # Select allocations for which the {Allocation#sourcefile sourcefile} does
    # not include `pattern`.
    #
    # `#not_from` can be called multiple times, adding to `@wheres`. See
    # documentation for {AllocationsProxy} for more information about chaining.
    #
    # @param [String] pattern the partial file path to match against, in the
    #   {Allocation#sourcefile Allocation's sourcefile}.
    def not_from(pattern)
      @wheres << Proc.new do |allocations|
        allocations.reject { |allocation| allocation.sourcefile[pattern] }
      end

      self
    end

    # Select allocations for which the {Allocation#sourcefile sourcefile}
    # includes the present working directory.
    #
    # `#from_pwd` can be called multiple times, adding to `@wheres`. See
    # documentation for {AllocationsProxy} for more information about chaining.
    def from_pwd
      @wheres << Proc.new do |allocations|
        allocations.select { |allocation| allocation.sourcefile[@pwd] }
      end

      self
    end

    # Group allocations by one or more attributes, that is, a list of symbols.
    # Commonly, you might want to group allocations by:
    #
    # * :sourcefile, :sourceline, :class
    # * :sourcefile, :method_id, :class
    # * :classpath, :method_id, :class
    #
    # In this case, `:class` is the class of the allocated object (as opposed
    # to `:classpath`, the classpath where the allocation occured).
    def group_by(*args)
      @group_keys = args

      @group_by = Proc.new do |allocations|
        getters = attribute_getters(@group_keys)

        allocations.group_by do |allocation|
          getters.map { |getter| getter.call(allocation) }
        end
      end

      self
    end

    # Select allocations that match `conditions`.
    #
    # @param [Hash] conditions pairs of attribute names and values to be matched amongst allocations.
    #
    # @example select allocations of String objects:
    #   allocations.where(class: String)
    def where(conditions)
      @wheres << Proc.new do |allocations|
        conditions = conditions.inject({}) do |memo, pair|
          faux, value = *pair
          getter = attribute_getters([faux]).first
          memo.merge(getter => value)
        end

        allocations.select do |allocation|
          conditions.all? { |getter, value| getter.call(allocation) == value }
        end
      end

      self
    end

    def attribute_getters(faux_attributes)
      faux_attributes.map do |faux|
        if faux == :sourcefile
          lambda { |allocation| allocation.sourcefile(@alias_paths) }
        elsif Allocation::HELPERS.include?(faux) ||
              Allocation::ATTRIBUTES.include?(faux)
          lambda { |allocation| allocation.__send__(faux) }
        else
          lambda { |allocation| allocation.object.__send__(faux) }
        end
      end
    end
    private :attribute_getters

    # Map to bytes via {Allocation#memsize #memsize}. This is done in one of
    # two ways:
    #
    # * If the current result set is an Array, then this transform just maps
    #   each Allocation to its `#memsize`.
    # * If the current result set is a Hash (meaning it has been grouped), then
    #   this transform maps each value in the Hash (which is an Array of
    #   Allocations) to the sum of the Allocation `#memsizes` within.
    def bytes
      @mappers << Proc.new do |allocations|
        if allocations.is_a? Array
          allocations.map(&:memsize)
        elsif allocations.is_a? Hash
          bytes_h = {}
          allocations.each do |key, allocations|
            bytes_h[key] = allocations.inject(0) { |sum, allocation| sum + allocation.memsize }
          end
          bytes_h
        end
      end

      self
    end

    # default columns for the tabular output
    DEFAULT_COLUMNS = [:sourcefile, :sourceline, :class_path, :method_id, :memsize, :class]

    # columns that should be right-aligned for the tabular output
    NUMERIC_COLUMNS = [:sourceline, :memsize]

    # Resolve the AllocationsProxy (by calling {#to_a}) and return tabular
    # information about the Allocations as a String.
    #
    # @param [Array<Symbol>] columns a list of columns to print out
    #
    # @return [String] information about the Allocations, in a tabular format
    def to_text(columns: DEFAULT_COLUMNS)
      resolved = to_a

      # if resolved is an Array of Allocations
      if resolved.is_a?(Array) && resolved.first.is_a?(Allocation)
        to_text_from_plain(resolved, columns: columns)

      # if resolved is a Hash (was grouped)
      elsif resolved.is_a?(Hash)
        to_text_from_groups(resolved)
      end
    end

    # Resolve all transformations, and convert the resultant Array to JSON.
    def to_json
      to_a.to_json
    end

    # Return tabular information about the un-grouped list of Allocations.
    #
    # @private
    def to_text_from_plain(resolved, columns: DEFAULT_COLUMNS)
      getters = attribute_getters(columns)

      widths = getters.each_with_index.map do |attr, idx|
        (resolved.map { |a| attr.call(a).to_s.size } << columns[idx].to_s.size).max
      end

      text = []

      text << columns.each_with_index.map { |attr, idx|
        attr.to_s.center(widths[idx])
      }.join("  ").rstrip

      text << widths.map { |width| "-" * width }.join("  ")

      text += resolved.map { |allocation|
        getters.each_with_index.map { |getter, idx|
          value = getter.call(allocation).to_s
          NUMERIC_COLUMNS.include?(columns[idx]) ? value.rjust(widths[idx]) : value.ljust(widths[idx])
        }.join("  ").rstrip
      }

      text.join("\n")
    end
    private :to_text_from_plain

    # Return tabular information about the grouped Allocations.
    #
    # @private
    def to_text_from_groups(resolved)
      columns = @group_keys + ["count"]

      keys = resolved.is_a?(Hash) ? resolved.keys : resolved.map(&:first)
      widths = columns.each_with_index.map do |column, idx|
        (keys.map { |group| group[idx].to_s.size } << columns[idx].to_s.size).max
      end

      text = []

      text << columns.each_with_index.map { |attr, idx|
        attr.to_s.center(widths[idx])
      }.join("  ").rstrip

      text << widths.map { |width| "-" * width }.join("  ")

      text += resolved.map { |group, allocations|
        line = group.each_with_index.map { |attr, idx|
          NUMERIC_COLUMNS.include?(columns[idx]) ?
            attr.to_s.rjust(widths[idx]) :
            attr.to_s.ljust(widths[idx])
        }.join("  ")

        line << "  " + allocations.size.to_s.rjust(5)
      }

      text.join("\n")
    end
    private :to_text_from_groups
  end
end
