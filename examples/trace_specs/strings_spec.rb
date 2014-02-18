require "pry"

require_relative File.join("..", "..", "lib", "allocation_stats")
require_relative "strings"
AllocationStats.trace_rspec

describe "Array of Strings" do
  it "allocates Strings and Arrays" do
    expect(an_array_of_strings).to include(foo)
  end

  it "allocates more Strings" do
    expect(teamwork).to include(tea)
  end
end
