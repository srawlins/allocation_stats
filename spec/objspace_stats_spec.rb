require_relative "spec_helper"

describe ObjectSpace::Stats do
  it "should only track new objects" do
    existing_array = [1,2,3,4,5]

    stats = ObjectSpace::Stats.new do
      new_array = [1,2,3,4,5]
    end

    stats.new_allocations.class.should be Array
    stats.new_allocations.size.should == 1
  end

  it "should only track new objects" do
    existing_array = [1,2,3,4,5]

    stats = ObjectSpace::Stats.new do
      new_object = Object.new
      new_array  = []
      new_string = ""
    end

    stats.new_allocations.class.should be Array
    stats.new_allocations.size.should == 3
  end

  it "should track new objects by path" do
    existing_array = [1,2,3,4,5]

    stats = ObjectSpace::Stats.new do
      new_string     = "stringy string"
      another_string = "another string"
    end

    stats.new_allocations_by_file.class.should eq Hash
    stats.new_allocations_by_file.keys.size.should == 1
    stats.new_allocations_by_file.keys.first.should eq __FILE__
    stats.new_allocations_by_file[__FILE__].class.should eq Array
    stats.new_allocations_by_file[__FILE__].size.should == 2
  end

  it "should track new objects by path" do
    existing_array = [1,2,3,4,5]

    stats = ObjectSpace::Stats.new do
      new_string     = "stringy string"
      another_string = "another string"
      a_foreign_string = allocate_a_string_from_spec_helper
    end

    stats.new_allocations_by_file.keys.size.should == 2
    stats.new_allocations_by_file.keys.should include(__FILE__)
    stats.new_allocations_by_file.keys.any? { |file| file["spec_helper"] }.should be_true
  end

  it "should track new objects by path and class" do
    existing_array = [1,2,3,4,5]

    stats = ObjectSpace::Stats.new do
      new_string     = "stringy string"
      another_string = "another string"
      an_array       = [1,1,2,3,5,8,13,21,34,55]
      a_foreign_string = allocate_a_string_from_spec_helper
    end

    stats.new_allocations_by(:@sourcefile, :class).keys.size.should == 3
    stats.new_allocations_by(:@sourcefile, :class).keys.should include([__FILE__, String])
    stats.new_allocations_by(:@sourcefile, :class).keys.should include([__FILE__, Array])
  end

  it "should track new bytes by path and class" do
    existing_array = [1,2,3,4,5]

    stats = ObjectSpace::Stats.new do
      new_string     = "stringy string"                      # 1: String from here
      another_string = "another string"
      an_array       = [1,1,2,3,5,8,13,21,34,55]             # 2: Array from here
      a_foreign_string = allocate_a_string_from_spec_helper  # 3: String from spec_helper

      class A; end                                           # 4: Class from here
      an_a = A.new                                           # 5: A from here
    end

    stats.new_bytes_by(:@sourcefile, :class).keys.size.should == 5
  end

  it "should track new allocations in pwd" do
    existing_array = [1,2,3,4,5]

    stats = ObjectSpace::Stats.new do
      new_string     = "stringy string"           # 1: String from here
      another_string = "another string"
      an_array       = [1,1,2,3,5,8,13,21,34,55]  # 2: Array from here
      a_range        = "aaa".."zzz"
      y = YAML.dump(["one string", "two string"]) # lots OF objects not from here
    end

    stats.new_allocations_from_pwd(:class).keys.size.should == 3
    stats.new_allocations_from_pwd(:class)[String].size.should == 6
    stats.new_allocations_from_pwd(:class)[Array].size.should == 3  # one for empty *args in YAML.dump
    stats.new_allocations_from_pwd(:class)[Range].size.should == 1
  end
end
