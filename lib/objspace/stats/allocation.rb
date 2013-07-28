require "json"

class ObjectSpace::Stats
  class Allocation
    PWD = Dir.pwd
    Helpers = [:class_plus]
    attr_accessor :object,
                  :memsize, :sourcefile
    attr_reader :class_path, :method_id, :sourceline

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

    def to_json
      {
        "memsize" => @memsize,
        "file" => @sourcefile,
        "line" => @sourceline,
        "class" => @object.class.name,
        "class_plus" => class_plus
      }.to_json
    end

    def element_classes(classes)
      if classes.size == 1
        classes.first
      elsif classes.size < 4
        classes.join(",")
      else
        nil
      end
    end
    private :element_classes
  end
end
