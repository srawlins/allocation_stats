require "objspace"
require_relative "stats/allocation"

class ObjectSpace::Stats
  attr_accessor :new_allocations

  def initialize
    @pwd = Dir.pwd

    GC.start

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
  end

  def new_allocations_by(*args)
    @new_allocations.group_by do |allocation|
      args.map do |arg|
        if arg.to_s[0] == "@"
          allocation.instance_variable_get(arg)
        else
          allocation.object.send(arg)
        end
      end
    end
  end

  def new_allocations_by_file
    @new_allocations.group_by(&:sourcefile)
  end

  def new_allocations_from_pwd(*args)
    from_pwd = @new_allocations.select { |allocation| allocation.sourcefile[@pwd] }
    if args.empty?
      from_pwd
    else
      group_by_multiple(from_pwd, *args)
    end
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

  def new_bytes_by(*args)
    bytes = {}
    new_allocations_by(*args).each do |key, allocations|
      bytes[key] = 0
      allocations.each { |allocation| bytes[key] += allocation.memsize }
    end
    bytes
  end
end
