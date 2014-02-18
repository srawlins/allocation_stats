class AllocationStats
  def self.trace_rspec
    @top_sites = []

    if (!const_defined?(:RSpec))
      raise StandardError, "Cannot trace RSpec until RSpec is loaded"
    end

    ::RSpec.configure do |config|
      config.around do |example|
        # TODO s/false/some config option/
        if true  # wrap loosely
          stats = AllocationStats.trace { example.run }
        else      # wrap tightly
          # Super hacky, but presumably more correct results?
          stats = AllocationStats.new
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
    end

    at_exit do
      puts AllocationStats.top_sites_text
    end
  end

  # A sorted list of the top "sites", that is, top file/line/class groups,
  # encountered while tracing RSpec.
  def self.top_sites
    @top_sites
  end

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
      @top_sites << { key: k, location: location, count: v.size }
    end

    @top_sites = @top_sites.sort_by! { |site| -site[:count] }[0...limit]
  end

  # Textual String representing the sorted list of the top allocation sites.
  # For each site, this String includes the number of allocations, the class,
  # the sourcefile, the sourceline, and the location of the RSpec spec.
  def self.top_sites_text
    return "" if @top_sites.empty?

    result = "Top #{@top_sites.size} allocation sites:\n"
    @top_sites.each do |site|
      result << "  %s allocations of %s at %s:%d\n" % [site[:count], site[:key][2], site[:key][0], site[:key][1]]
      result << "    during %s\n" % [site[:location]]
    end

    result
  end
end
