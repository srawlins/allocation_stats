require 'objspace'

ObjectSpace.trace_object_allocations do
  a = [2,3,5,7,11,13,17,19,23,29,31]
  puts ObjectSpace.allocation_sourcefile(a)
  puts ObjectSpace.allocation_sourceline(a)
end
