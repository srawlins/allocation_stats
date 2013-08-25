# Copyright 2013 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require "json"

class ObjectSpace::Stats
  class Allocation
    # a convenience constants
    PWD = Dir.pwd

    # a list of helper methods that Allocation provides on top of the object that was allocated.
    Helpers = [:class_plus]

    attr_accessor :memsize, :sourcefile

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
      #if @sourcefile && @sourcefile[PWD]
        #@sourcefile.sub!(PWD, "<PWD>")
      #elsif @sourcefile && @sourcefile[ObjectSpace::Stats::Rubylibdir]
      if @sourcefile && @sourcefile[ObjectSpace::Stats::Rubylibdir]
        @sourcefile.sub!(ObjectSpace::Stats::Rubylibdir, "<RUBYLIBDIR>")
      elsif @sourcefile && @sourcefile[ObjectSpace::Stats::GemDir]
        @sourcefile.sub!(ObjectSpace::Stats::GemDir, "<GEMDIR>")
      end
      @sourceline = ObjectSpace.allocation_sourceline(object)
      @class_path = ObjectSpace.allocation_class_path(object)
      @method_id  = ObjectSpace.allocation_method_id(object)
    end

    def file; @sourcefile; end
    #def line; @sourceline; end
    alias :line :sourceline

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

    # @return [String] the name of the Rubygem where this allocation occurred.
    # @return [nil] if this allocation did not occur in a Rubygem.
    #
    # Override Rubygems' Kernel#gem
    def gem
      gem_regex = /<GEMDIR>#{File::SEPARATOR}
        gems#{File::SEPARATOR}
        (?<gem_name>[^#{File::SEPARATOR}]+)#{File::SEPARATOR}
      /x
      match = gem_regex.match(@sourcefile)
      match && match[:gem_name]
    end

    # Convert into a JSON string, which can be used in rack-objectspace-stats's
    # interactive mode.
    def to_json
      {
        "memsize" => @memsize,
        "class_path" => @class_path,
        "method_id" => @method_id,
        "file" => @sourcefile,
        "line" => @sourceline,
        "class" => @object.class.name,
        "class_plus" => class_plus
      }.to_json
    end

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
