class ObjectSpace::Stats
  class Allocation
    attr_accessor :object,
                  :memsize, :sourcefile

    def initialize(object)
      @object = object
      @memsize    = ObjectSpace.memsize_of(object)
      @sourcefile = ObjectSpace.allocation_sourcefile(object)
      @sourceline = ObjectSpace.allocation_sourceline(object)
    end

    def file; @sourcefile; end
    def line; @sourceline; end
  end
end
