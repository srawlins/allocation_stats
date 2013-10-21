class MyClass
  def my_method
    @hash = {2 => "foo", 3 => "bar", 5 => "baz"}
    @string = "quux"
  end
end

require File.join(__dir__, "..", "lib", "allocation_stats")

stats = AllocationStats.trace { MyClass.new.my_method }
puts stats.allocations.to_text(columns: [:sourcefile, :sourceline, :class_path, :method_id, :class])
