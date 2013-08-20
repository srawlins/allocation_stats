# Copyright 2013 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

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

  it "should only track new objects; Hash String count twice :(" do
    existing_array = [1,2,3,4,5]

    stats = ObjectSpace::Stats.new do
      new_hash = {"foo" => "bar", "baz" => "quux"}
    end

    stats.new_allocations.size.should == 7
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

    results = stats.allocations.group_by(:@sourcefile).all
    results.class.should eq Hash
    results.keys.size.should == 1
    results.keys.first.should eq [__FILE__]
    results[[__FILE__]].class.should eq Array
    results[[__FILE__]].size.should == 2
  end

  it "should track new objects by path" do
    existing_array = [1,2,3,4,5]

    stats = ObjectSpace::Stats.new do
      new_string     = "stringy string"
      another_string = "another string"
      a_foreign_string = allocate_a_string_from_spec_helper
    end

    results = stats.allocations.group_by(:@sourcefile).all
    results.keys.size.should == 2
    results.keys.should include([__FILE__])
    results.keys.any? { |file| file[0]["spec_helper"] }.should be_true
  end

  it "should track new objects by path and class" do
    existing_array = [1,2,3,4,5]

    stats = ObjectSpace::Stats.new do
      new_string     = "stringy string"
      another_string = "another string"
      an_array       = [1,1,2,3,5,8,13,21,34,55]
      a_foreign_string = allocate_a_string_from_spec_helper
    end

    results = stats.allocations.group_by(:@sourcefile, :class).all
    results.keys.size.should == 3
    results.keys.should include([__FILE__, String])
    results.keys.should include([__FILE__, Array])
  end

  it "should track new objects by path and class_name (Array with 1x type)" do
    stats = ObjectSpace::Stats.new do
      square_groups = []
      10.times do |i|
        square_groups << [(4*i+0)**2, (4*i+1)**2, (4*i+2)**2, (4*i+3)**2]
      end
    end

    results = stats.allocations.group_by(:@sourcefile, :class_plus).all
    results.keys.size.should == 2
    results.keys.should include([__FILE__, "Array<Array>"])
    results.keys.should include([__FILE__, "Array<Fixnum>"])
  end

  it "should track new objects by path and class_name (Array with 2-3x type)" do
    stats = ObjectSpace::Stats.new do
      two_classes = [1,2,3,"a","b","c"]
      three_classes = [1,1.0,"1"]
    end

    results = stats.allocations.group_by(:@sourcefile, :class_plus).all
    results.keys.size.should == 3
    results.keys.should include([__FILE__, "Array<Fixnum,String>"])
    results.keys.should include([__FILE__, "Array<Fixnum,Float,String>"])
  end

  it "should track new objects by path and class_name (Arrays with same size)" do
    stats = ObjectSpace::Stats.new do
      ary = []
      10.times do
        ary << [1,2,3,4,5]
      end
    end

    results = stats.allocations.group_by(:@sourcefile, :class_plus).all
    results.keys.size.should == 2
    results.keys.should include([__FILE__, "Array<Fixnum>"])
  end

  it "should track new objects by class_path, method_id and class" do
    existing_array = [1,2,3,4,5]

    stats = ObjectSpace::Stats.new do
      new_string       = "stringy string"
      another_string   = "another string"
      an_array         = [1,1,2,3,5,8,13,21,34,55]
      a_foreign_string = allocate_a_string_from_spec_helper
    end

    results = stats.allocations.group_by(:@class_path, :@method_id, :class).all
    results.keys.size.should == 3
    # Things allocated inside rspec describe and it blocks have nil as the
    # method_id.
    results.keys.should include([nil, nil, String])
    results.keys.should include([nil, nil, Array])
    results.keys.should include(["Object", :allocate_a_string_from_spec_helper, String])
  end

  it "should track new bytes" do
    stats = ObjectSpace::Stats.new do
      an_array       = [1,1,2,3,5,8,13,21,34,55]
    end

    byte_sums = stats.allocations.bytes.all
    byte_sums.size.should == 1
    byte_sums[0].should be 80
  end

  it "should track new bytes by path and class" do
    stats = ObjectSpace::Stats.new do
      new_string     = "stringy string"                      # 1: String from here
      an_array       = [1,1,2,3,5,8,13,21,34,55]             # 2: Array from here
      a_foreign_string = allocate_a_string_from_spec_helper  # 3: String from spec_helper

      class A; end                                           # 4: Class from here
      an_a = A.new                                           # 5: A from here
    end

    byte_sums = stats.allocations.group_by(:@sourcefile, :class).bytes.all
    byte_sums.keys.size.should == 5
    byte_sums.keys.should include([__FILE__, Array])
    byte_sums[[__FILE__, Array]].should eq 80  # 10 Fixnums * 8 bytes/Fixnum
  end

  it "should track new allocations in pwd" do
    existing_array = [1,2,3,4,5]

    stats = ObjectSpace::Stats.new do
      new_string     = "stringy string"           # 1: String from here
      another_string = "another string"
      an_array       = [1,1,2,3,5,8,13,21,34,55]  # 2: Array from here
      a_range        = "aaa".."zzz"
      y = YAML.dump(["one string", "two string"]) # lots of objects not from here
    end

    results = stats.allocations.from_pwd.group_by(:class).all
    results.keys.size.should == 3
    results[[String]].size.should == 6
    results[[Array]].size.should == 3  # one for empty *args in YAML.dump
    results[[Range]].size.should == 1
  end

  it "should pass itself to Yajl::Encoder.encode correctly" do
    stats = ObjectSpace::Stats.new do
      new_hash = {0 => "foo", 1 => "bar"}
    end

    Yajl::Encoder.encode(stats.allocations.to_a).should eq \
      "[{\"memsize\":192,\"file\":\"#{__FILE__}\",\"line\":170,\"class_plus\":\"Hash\"}," +
        "{\"memsize\":0,\"file\":\"#{__FILE__}\",\"line\":170,\"class_plus\":\"String\"}," +
        "{\"memsize\":0,\"file\":\"#{__FILE__}\",\"line\":170,\"class_plus\":\"String\"}]"
  end

  it "should shorten paths of stuff in Rubylibdir" do
    stats = ObjectSpace::Stats.new do
      y = YAML.dump(["one string", "two string"]) # lots of objects from Rbconfig::CONFIG["rubylibdir"]
    end

    files = stats.allocations.group_by(:@sourcefile, :class).all.keys.map(&:first)
    files.should include("<RUBYLIBDIR>/psych/nodes/node.rb")
  end

  it "should shorten paths of stuff in gems" do
    stats = ObjectSpace::Stats.new do
      j = Yajl.dump(["one string", "two string"]) # lots of objects from Rbconfig::CONFIG["rubylibdir"]
    end

    files = stats.allocations.group_by(:@sourcefile, :class).all.keys.map(&:first)
    files.should include("<GEMDIR>/gems/yajl-ruby-1.1.0/lib/yajl.rb")
  end

  it "should track new objects by gem" do
    stats = ObjectSpace::Stats.new do
      j = Yajl.dump(["one string", "two string"]) # lots of objects from Rbconfig::CONFIG["rubylibdir"]
    end

    gems = stats.allocations.group_by(:@gem, :class).all.keys.map(&:first)
    gems.should include("yajl-ruby-1.1.0")
    gems.should include(nil)
  end
end
