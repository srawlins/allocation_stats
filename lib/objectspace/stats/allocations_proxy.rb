# Copyright 2013 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

class ObjectSpace::Stats
  class AllocationsProxy

    def initialize(allocations)
      @allocations = allocations
      @pwd = Dir.pwd
      @wheres = []
      @group_by = nil
      @mappers  = []
    end

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

    def sorted_by_size
      @mappers << Proc.new do |allocations|
        allocations.sort_by { |key, value| -value.size }
      end

      self
    end

    def from(pattern)
      @wheres << Proc.new do |allocations|
        allocations.select { |allocation| allocation.sourcefile[pattern] }
      end

      self
    end

    def not_from(pattern)
      @wheres << Proc.new do |allocations|
        allocations.reject { |allocation| allocation.sourcefile[pattern] }
      end

      self
    end

    def from_pwd
      @wheres << Proc.new do |allocations|
        allocations.select { |allocation| allocation.sourcefile[@pwd] }
      end

      self
    end

    def group_by(*args)
      @group_by = Proc.new do |allocations|
        getters = attribute_getters(args)

        allocations.group_by do |allocation|
          getters.map { |getter| getter.call(allocation) }
        end
      end

      self
    end

    def where(hash)
      @wheres << Proc.new do |allocations|
        conditions = hash.inject({}) do |h, pair|
          faux, value = *pair
          getter = attribute_getters([faux]).first
          h.merge(getter => value)
        end

        allocations.select do |allocation|
          conditions.all? { |getter, value| getter.call(allocation) == value }
        end
      end

      self
    end

    def attribute_getters(faux_attributes)
      faux_attributes.map do |faux|
        if faux.to_s[0] == "@"
          # use the public API rather than that instance_variable; don't want false nils
          lambda { |allocation| allocation.send(faux.to_s[1..-1].to_sym) }
        elsif Allocation::Helpers.include? faux
          lambda { |allocation| allocation.send(faux) }
        else
          lambda { |allocation| allocation.object.send(faux) }
        end
      end
    end

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
  end
end
