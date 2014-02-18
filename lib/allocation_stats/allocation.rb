# Copyright 2014 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require "json"

class AllocationStats
  # Information about an individual allocation is captured in this class.
  class Allocation
    # a convenience constants
    PWD = Dir.pwd

    # a list of helper methods that Allocation provides on top of the object
    # that was allocated.
    HELPERS = [:class_plus, :gem]

    # a list of attributes that Allocation has on itself; inquiries in this
    # list should just use Allocation's attributes, rather than the internal
    # object's.
    ATTRIBUTES = [:sourcefile, :sourceline, :class_path, :method_id, :memsize]

    # @!attribute [rw] memsize
    # the memsize of the object which was allocated
    attr_accessor :memsize

    # @!attribute [r] class_path
    # the classpath of where the object was allocated
    attr_reader :class_path

    # @!attribute [r] method_id
    # the method ID of where the object was allocated
    attr_reader :method_id

    # @!attribute [r] object
    # the actual object that was allocated
    attr_reader :object

    # @!attribute [r] sourceline
    # the line in the sourcefile where the object was allocated
    attr_reader :sourceline

    def initialize(object)
      @object = object
      @memsize    = ObjectSpace.memsize_of(object)
      @sourcefile = ObjectSpace.allocation_sourcefile(object)
      @sourceline = ObjectSpace.allocation_sourceline(object)
      @class_path = ObjectSpace.allocation_class_path(object)
      @method_id  = ObjectSpace.allocation_method_id(object)
    end

    # the sourcefile where the object was allocated
    def file; @sourcefile; end

    alias :line :sourceline

    # If the source file has recognized paths in it, those portions of the full
    # path will be aliased like so:
    #
    # * the present work directory is aliased to "<PWD>"
    # * the Ruby lib directory (where the standard library lies) is aliased to
    #   "<RUBYLIBDIR>"
    # * the Gem directory (where all gems lie) is aliased to "<GEMDIR>"
    #
    # @return the source file, aliased.
    def sourcefile_alias
      case
      when @sourcefile[AllocationStats::RUBYLIBDIR]
        @sourcefile.sub(AllocationStats::RUBYLIBDIR, "<RUBYLIBDIR>")
      when @sourcefile[AllocationStats::GEMDIR]
        @sourcefile.sub(/#{AllocationStats::GEMDIR}\/gems\/([^\/]+)\//, '<GEM:\1>/')
      when @sourcefile[PWD]
        @sourcefile.sub(PWD, "<PWD>")
      else
        @sourcefile
      end
    end

    # Either the full source file (via `@sourcefile`), or the aliased source
    # file, via {#sourcefile_alias}
    #
    # @param [TrueClass] alias_path whether or not to alias the path
    def sourcefile(alias_path = false)
      alias_path ? sourcefile_alias : @sourcefile
    end

    # Returns class name, plus, for Arrays, extended information. When all of
    # the elements of the Array are instances of a total of three or fewer
    # classes, then those classes are listed in brackets. For example:
    #
    # @example Array with only Fixnum and Bignum elements
    #   allocation.class_plus  #=> "Array<Fixnum,Bignum>"
    # @example Array with elements of class A, B, C, and D
    #   allocation.class_plus  #=> "Array"
    # @example String (not an Array)
    #   allocation.class_plus  #=> "String"
    def class_plus
      case @object
      when Array
        object_classes = element_classes(@object.map {|e| e.class }.uniq)
        if object_classes
          "Array<#{object_classes}>"
        else
          "Array"
        end
      else
        @object.class.name
      end
    end

    # Override Rubygems' Kernel#gem
    #
    # @return [String] the name of the Rubygem where this allocation occurred.
    # @return [nil] if this allocation did not occur in a Rubygem.
    def gem
      gem_regex = /#{AllocationStats::GEMDIR}#{File::SEPARATOR}
        gems#{File::SEPARATOR}
        (?<gem_name>[^#{File::SEPARATOR}]+)#{File::SEPARATOR}
      /x
      match = gem_regex.match(sourcefile)
      match && match[:gem_name]
    end

    # Convert into a JSON string, which can be used in rack-allocation_stats's
    # interactive mode.
    def as_json
      {
        "memsize"      => @memsize,
        "class_path"   => @class_path,
        "method_id"    => @method_id,
        "file"         => sourcefile_alias,
        "file (raw)"   => @sourcefile,
        "line"         => @sourceline,
        "class"        => @object.class.name,
        "class_plus"   => class_plus
      }
    end

    # Convert into a JSON string, which can be used in rack-allocation_stats's
    # interactive mode.
    def to_json(*a)
      as_json.to_json(*a)
    end

    # @return either _the one_ class passed in, the two-to-four classes passed
    #   in separated by commas, or `nil` if more than four classes were passed
    #   in.
    #
    # @api private
    def element_classes(classes)
      if classes.size == 1
        classes.first
      elsif classes.size > 1 && classes.size < 4
        classes.join(",")
      else
        nil
      end
    end
    private :element_classes
  end
end
