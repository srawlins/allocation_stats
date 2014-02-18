# Copyright 2014 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require_relative File.join("spec_helper")

describe "AllocationStats.trace_rspec" do
  let(:example_group) do
    RSpec::Core::ExampleGroup.describe("group description")
  end

  describe "top_sites" do
    before do
      AllocationStats.top_sites = []  # clear it; TODO: API?

      @a = [["<PWD>/foo.rb", 2, String], [:placeholder, :placeholder, :placeholder, :placeholder, :placeholder]]
      @b = [["<PWD>/foo.rb", 3, Hash],   [:placeholder, :placeholder, :placeholder]]
      @c = [["<PWD>/foo.rb", 1, Array],  [:placeholder, :placeholder]]
      @d = [["<PWD>/foo.rb", 1, String], [:placeholder]]
      @e = [["<PWD>/foo.rb", 4, String], [:placeholder, :placeholder, :placeholder, :placeholder, :placeholder, :placeholder]]
      @f = [["<PWD>/foo.rb", 4, Array],  [:placeholder]]

      @allocations01 = [@a, @b, @c, @d].to_h
      @allocations02 = [@b, @c, @e, @f].to_h

      @spec_location01 = "./spec/foo_spec.rb:3"
      @spec_location02 = "./spec/foo_spec.rb:7"
    end

    it "adds allocation groups to the top allocation points, limiting each set of allocations" do
      AllocationStats.add_to_top_sites(@allocations01, @spec_location01, 3)

      expect(AllocationStats.top_sites.size).to be(3)

      expect(AllocationStats.top_sites[0][:key]).to eq(@a.first)
      expect(AllocationStats.top_sites[0][:location]).to eq(@spec_location01)
      expect(AllocationStats.top_sites[0][:count]).to eq(5)

      expect(AllocationStats.top_sites[1][:key]).to eq(@b.first)
      expect(AllocationStats.top_sites[1][:location]).to eq(@spec_location01)
      expect(AllocationStats.top_sites[1][:count]).to eq(3)

      expect(AllocationStats.top_sites[2][:key]).to eq(@c.first)
      expect(AllocationStats.top_sites[2][:location]).to eq(@spec_location01)
      expect(AllocationStats.top_sites[2][:count]).to eq(2)
    end

    it "adds allocation groups to the top allocation points, organizing when too many" do
      AllocationStats.add_to_top_sites(@allocations01, @spec_location01, 5)
      AllocationStats.add_to_top_sites(@allocations02, @spec_location02, 5)

      expect(AllocationStats.top_sites.size).to be(5)

      expect(AllocationStats.top_sites[0][:key]).to eq(@e.first)
      expect(AllocationStats.top_sites[0][:location]).to eq(@spec_location02)
      expect(AllocationStats.top_sites[0][:count]).to eq(6)

      expect(AllocationStats.top_sites[1][:key]).to eq(@a.first)
      expect(AllocationStats.top_sites[1][:location]).to eq(@spec_location01)
      expect(AllocationStats.top_sites[1][:count]).to eq(5)

      expect(AllocationStats.top_sites[2][:key]).to eq(@b.first)
      expect(AllocationStats.top_sites[2][:location]).to eq(@spec_location01)
      expect(AllocationStats.top_sites[2][:count]).to eq(3)

      # The sort is always stable
      expect(AllocationStats.top_sites[3][:key]).to eq(@b.first)
      expect(AllocationStats.top_sites[3][:location]).to eq(@spec_location02)
      expect(AllocationStats.top_sites[3][:count]).to eq(3)

      expect(AllocationStats.top_sites[4][:key]).to eq(@c.first)
      expect(AllocationStats.top_sites[4][:location]).to eq(@spec_location01)
      expect(AllocationStats.top_sites[4][:count]).to eq(2)
    end
  end

  it "prints top allocation sites after rspecs have run" do
    AllocationStats.trace_rspec

    example_group.example do
      expect(["abc", "def", "ghi"]).to include("abc")
    end

    line = __LINE__ - 4
    example_group.run(NullObject.new)
    output = AllocationStats.top_sites_text

    expect(output).to include("Top 2 allocation sites:\n")
    expect(output).to include("  4 allocations of String at <PWD>/spec/trace_rspec_spec.rb:#{line+1}\n")
    expect(output).to include("    during ./spec/trace_rspec_spec.rb:#{line}\n")
    expect(output).to include("  3 allocations of Array at <PWD>/spec/trace_rspec_spec.rb:#{line+1}\n")
    expect(output).to include("    during ./spec/trace_rspec_spec.rb:#{line}\n")
  end
end
