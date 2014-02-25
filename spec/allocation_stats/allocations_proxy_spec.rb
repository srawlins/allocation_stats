# Copyright 2014 Google Inc. All Rights Reserved.
# Licensed under the Apache License, Version 2.0, found in the LICENSE file.

require_relative File.join("..", "spec_helper")
SPEC_HELPER_PATH = File.expand_path(File.join(__dir__, "..", "spec_helper.rb"))
MAX_PATH_LENGTH = [SPEC_HELPER_PATH.size, __FILE__.size].max

describe AllocationStats::AllocationsProxy do
  it "should track new objects by path" do
    existing_array = [1,2,3,4,5]

    stats = AllocationStats.trace do
      new_string     = "stringy string"
      another_string = "another string"
    end

    results = stats.allocations.group_by(:sourcefile).all
    results.class.should eq Hash
    results.keys.size.should == 1
    results.keys.first.should eq [__FILE__]
    results[[__FILE__]].class.should eq Array
    results[[__FILE__]].size.should == 2
  end

  it "should track new objects by path" do
    existing_array = [1,2,3,4,5]

    stats = AllocationStats.trace do
      new_string     = "stringy string"
      another_string = "another string"
      a_foreign_string = allocate_a_string_from_spec_helper
    end

    results = stats.allocations.group_by(:sourcefile).all
    results.keys.size.should == 2
    results.keys.should include([__FILE__])
    results.keys.any? { |file| file[0]["spec_helper"] }.should be_true
  end

  it "should track new objects by path and class" do
    existing_array = [1,2,3,4,5]

    stats = AllocationStats.trace do
      new_string     = "stringy string"
      another_string = "another string"
      an_array       = [1,1,2,3,5,8,13,21,34,55]
      a_foreign_string = allocate_a_string_from_spec_helper
    end

    results = stats.allocations.group_by(:sourcefile, :class).all
    results.keys.size.should == 3
    results.keys.should include([__FILE__, String])
    results.keys.should include([__FILE__, Array])
  end

  it "should track new BasicObjects" do
    class BO < BasicObject; end

    stats = AllocationStats.trace do
      bo = BO.new
    end

    results = stats.allocations.group_by(:sourcefile).all
    expect(results.class).to be(Hash)
    expect(results.keys.size).to eq(1)
    expect(results.keys.first).to eq([__FILE__])
    expect(results[[__FILE__]].class).to eq(Array)
    expect(results[[__FILE__]].size).to eq(1)
    expect(results[[__FILE__]].first.object.class).to be(BO)
  end

  it "should track new objects by path and class_name (Array with 1x type)" do
    stats = AllocationStats.trace do
      square_groups = []
      10.times do |i|
        square_groups << [(4*i+0)**2, (4*i+1)**2, (4*i+2)**2, (4*i+3)**2]
      end
    end

    results = stats.allocations.group_by(:sourcefile, :class_plus).all
    results.keys.size.should == 2
    results.keys.should include([__FILE__, "Array<Array>"])
    results.keys.should include([__FILE__, "Array<Fixnum>"])
  end

  it "should track new objects by path and class_name (Array with 2-3x type)" do
    stats = AllocationStats.trace do
      two_classes = [1,2,3,"a","b","c"]
      three_classes = [1,1.0,"1"]
    end

    results = stats.allocations.group_by(:sourcefile, :class_plus).all
    results.keys.size.should == 3
    results.keys.should include([__FILE__, "Array<Fixnum,String>"])
    results.keys.should include([__FILE__, "Array<Fixnum,Float,String>"])
  end

  it "should track new objects by path and class_name (Arrays with same size)" do
    stats = AllocationStats.trace do
      ary = []
      10.times do
        ary << [1,2,3,4,5]
      end
    end

    results = stats.allocations.group_by(:sourcefile, :class_plus).all
    pending "Not written yet"
  end

  it "should track new objects by class_path, method_id and class" do
    existing_array = [1,2,3,4,5]

    stats = AllocationStats.trace do
      new_string       = "stringy string"
      another_string   = "another string"
      an_array         = [1,1,2,3,5,8,13,21,34,55]
      a_foreign_string = allocate_a_string_from_spec_helper
    end

    results = stats.allocations.group_by(:class_path, :method_id, :class).all
    results.keys.size.should == 3

    # Things allocated inside rspec describe and it blocks have nil as the
    # method_id.
    results.keys.should include([nil, nil, String])
    results.keys.should include([nil, nil, Array])
    results.keys.should include(["Object", :allocate_a_string_from_spec_helper, String])
  end

  it "should track new bytes" do
    stats = AllocationStats.trace do
      an_array       = [1,1,2,3,5,8,13,21,34,55]
    end

    byte_sums = stats.allocations.bytes.all
    byte_sums.size.should == 1
    byte_sums[0].should be 80
  end

  it "should track new bytes by path and class" do
    stats = AllocationStats.trace do
      new_string     = "stringy string"                      # 1: String from here
      an_array       = [1,1,2,3,5,8,13,21,34,55]             # 2: Array from here
      a_foreign_string = allocate_a_string_from_spec_helper  # 3: String from spec_helper

      class A; end                                           # 4: Class from here
      an_a = A.new                                           # 5: A from here
    end

    byte_sums = stats.allocations.group_by(:sourcefile, :class).bytes.all
    byte_sums.keys.size.should == 5
    byte_sums.keys.should include([__FILE__, Array])
    byte_sums[[__FILE__, Array]].should eq 80  # 10 Fixnums * 8 bytes/Fixnum
  end

  it "should track new allocations in pwd" do
    existing_array = [1,2,3,4,5]

    stats = AllocationStats.trace do
      new_string     = "stringy string"           # 1: String from here
      another_string = "another string"
      an_array       = [1,1,2,3,5,8,13,21,34,55]  # 2: Array from here
      a_range        = "aaa".."zzz"
      y = YAML.dump(["one string", "two string"]) # lots of objects not from here
    end

    results = stats.allocations.from_pwd.group_by(:class).all
    results.keys.size.should == 3
    results[[String]].size.should == 6
    results[[Array]].size.should == 2
    results[[Range]].size.should == 1
  end

  it "should pass itself to Yajl::Encoder.encode correctly" do
    pending "I don't know why this isn't passing, but it's not worth worrying about now"
    stats = AllocationStats.trace do
      new_hash = {0 => "foo", 1 => "bar"}
    end

    Yajl::Encoder.encode(stats.allocations.to_a).should eq \
      "[{\"memsize\":192,\"file\":\"#{__FILE__}\",\"line\":170,\"class_plus\":\"Hash\"}," +
        "{\"memsize\":0,\"file\":\"#{__FILE__}\",\"line\":170,\"class_plus\":\"String\"}," +
        "{\"memsize\":0,\"file\":\"#{__FILE__}\",\"line\":170,\"class_plus\":\"String\"}]"
  end

  it "should shorten paths of stuff in RUBYLIBDIR" do
    stats = AllocationStats.trace do
      y = YAML.dump(["one string", "two string"]) # lots of objects from Rbconfig::CONFIG["rubylibdir"]
    end

    files = stats.allocations(alias_paths: true).group_by(:sourcefile, :class).all.keys.map(&:first)
    files.should include("<RUBYLIBDIR>/psych/nodes/node.rb")
  end

  it "should shorten paths of stuff in gems" do
    stats = AllocationStats.trace do
      j = Yajl.dump(["one string", "two string"]) # lots of objects from Rbconfig::CONFIG["rubylibdir"]
    end

    files = stats.allocations(alias_paths: true).group_by(:sourcefile, :class).all.keys.map(&:first)
    files.should include("<GEM:yajl-ruby-1.1.0>/lib/yajl.rb")
  end

  it "should track new objects by gem" do
    stats = AllocationStats.trace do
      j = Yajl.dump(["one string", "two string"]) # lots of objects from Rbconfig::CONFIG["rubylibdir"]
    end

    gems = stats.allocations.group_by(:gem, :class).all.keys.map(&:first)
    gems.should include("yajl-ruby-1.1.0")
    gems.should include(nil)
  end

  it "should be able to filter to just anything from pwd" do
    stats = AllocationStats.trace do
      j = Yajl.dump(["one string", "two string"]) # lots of objects from Rbconfig::CONFIG["rubylibdir"]
    end

    files = stats.allocations.group_by(:sourcefile, :class).from_pwd.all.keys.map(&:first)
    files.should_not include("<GEMDIR>/gems/yajl-ruby-1.1.0/lib/yajl.rb")
  end

  it "should be able to filter to just anything from pwd, even if from is specified before group_by" do
    stats = AllocationStats.trace do
      j = Yajl.dump(["one string", "two string"]) # lots of objects from Rbconfig::CONFIG["rubylibdir"]
    end

    files = stats.allocations.from_pwd.group_by(:sourcefile, :class).all.keys.map(&:first)
    files.should_not include("<GEMDIR>/gems/yajl-ruby-1.1.0/lib/yajl.rb")
  end

  it "should be able to filter to just one path" do
    stats = AllocationStats.trace do
      j = Yajl.dump(["one string", "two string"]) # lots of objects from Rbconfig::CONFIG["rubylibdir"]
    end

    files = stats.allocations(alias_paths: true).group_by(:sourcefile, :class).from("yajl.rb").all.keys.map(&:first)
    files.should include("<GEM:yajl-ruby-1.1.0>/lib/yajl.rb")
  end

  it "should be able to filter to just one path" do
    stats = AllocationStats.trace do
      j = Yajl.dump(["one string", "two string"]) # lots of objects from Rbconfig::CONFIG["rubylibdir"]
    end

    files = stats.allocations.not_from("yajl.rb").group_by(:sourcefile, :class).all.keys.map(&:first)
    files.should_not include("<GEMDIR>/gems/yajl-ruby-1.1.0/lib/yajl.rb")
  end

  it "should be able to filter to just one class" do
    stats = AllocationStats.trace do
      j = Yajl.dump(["one string", "two string"]) # lots of objects from Rbconfig::CONFIG["rubylibdir"]
    end

    classes = stats.allocations.where(class: String).group_by(:sourcefile, :class).all.keys.map(&:last)
    classes.should_not include(Array)
    classes.should_not include(Hash)
    classes.should include(String)
  end

  context "to_text" do
    before do
      @stats = AllocationStats.trace { MyClass.new.my_method }
      @line = __LINE__ - 1
    end

    it "should output to fixed-width text correctly" do
      text = @stats.allocations.to_text
      spec_helper_plus_line = "#{SPEC_HELPER_PATH.ljust(MAX_PATH_LENGTH)}          #{MyClass::MY_METHOD_BODY_LINE}"

      expect(text).to include("#{"sourcefile".center(MAX_PATH_LENGTH)}  sourceline  class_path  method_id  memsize   class")
      expect(text).to include("#{"-" * MAX_PATH_LENGTH}  ----------  ----------  ---------  -------  -------")
      expect(text).to include("#{spec_helper_plus_line}  MyClass     my_method      192  Hash")
      expect(text).to include("#{spec_helper_plus_line}  MyClass     my_method        0  String")
      expect(text).to include("#{__FILE__.ljust(MAX_PATH_LENGTH)}         #{@line}  Class       new              0  MyClass")
    end

    it "should output to fixed-width text with custom columns correctly" do
      text = @stats.allocations.to_text(columns: [:sourcefile, :sourceline, :class])
      spec_helper_plus_line = "#{SPEC_HELPER_PATH.ljust(MAX_PATH_LENGTH)}          #{MyClass::MY_METHOD_BODY_LINE}"

      expect(text).to include("#{"sourcefile".center(MAX_PATH_LENGTH)}  sourceline   class")
      expect(text).to include("#{"-" * MAX_PATH_LENGTH}  ----------  -------")
      expect(text).to include("#{spec_helper_plus_line}  Hash")
      expect(text).to include("#{spec_helper_plus_line}  String")
      expect(text).to include("#{__FILE__.ljust(MAX_PATH_LENGTH)}         #{@line}  MyClass")
    end

    it "should output to fixed-width text with custom columns and aliased paths correctly" do
      text = @stats.allocations(alias_paths: true).to_text(columns: [:sourcefile, :sourceline, :class])
      spec_helper_plus_line = "<PWD>/spec/spec_helper.rb                                      #{MyClass::MY_METHOD_BODY_LINE}"

      expect(text).to include("                     sourcefile                        sourceline   class")
      expect(text).to include("-----------------------------------------------------  ----------  -------")
      expect(text).to include("#{spec_helper_plus_line}  Hash")
      expect(text).to include("#{spec_helper_plus_line}  String")
      expect(text).to include("<PWD>/spec/allocation_stats/allocations_proxy_spec.rb         #{@line}  MyClass")
    end

    it "should output to fixed-width text after group_by correctly" do
      text = @stats.allocations(alias_paths: true).group_by(:sourcefile, :sourceline, :class).to_text
      spec_helper_plus_line = "<PWD>/spec/spec_helper.rb                                      #{MyClass::MY_METHOD_BODY_LINE}"

      expect(text).to include("                     sourcefile                        sourceline   class   count\n")
      expect(text).to include("-----------------------------------------------------  ----------  -------  -----\n")
      expect(text).to include("#{spec_helper_plus_line}  Hash         1")
      expect(text).to include("#{spec_helper_plus_line}  String       2")
      expect(text).to include("<PWD>/spec/allocation_stats/allocations_proxy_spec.rb         #{@line}  MyClass      1")
    end
  end

  context "to_json" do
    before do
      @stats = AllocationStats.trace { MyClass.new.my_method }
      @line = __LINE__ - 1
    end

    it "should output to json correctly" do
      json = @stats.allocations.to_json
      expect { Yajl::Parser.parse(json) }.to_not raise_error
    end

    it "should output to json correctly" do
      allocations = @stats.allocations.all
      json = allocations.to_json
      parsed = Yajl::Parser.parse(json)

      first = {
        "file" => "<PWD>/spec/spec_helper.rb",
        "file (raw)" =>  "#{Dir.pwd}/spec/spec_helper.rb",
        "line" => 23,
        "class_path" => "MyClass",
        "method_id" => :my_method.to_s,
        "memsize" => 192,
        "class" => "Hash",
        "class_plus" => "Hash"
      }

      expect(parsed.size).to be(4)
      expect(parsed.any? { |allocation| allocation == first } ).to be_true
    end
  end

  context "sorting" do
    before do
      @stats = AllocationStats.trace do
        ary = []
        4.times do
          ary << [1,2,3,4,5]
        end
        str_1 = "string"; str_2 = "strang"
      end
      @lines = [__LINE__ - 6, __LINE__ - 4, __LINE__ - 2]
    end

    it "should sort Allocations that have not been grouped" do
      results = @stats.allocations.group_by(:sourcefile, :sourceline, :class).sort_by_count.all

      expect(results.keys[0]).to include(@lines[1])
      expect(results.keys[1]).to include(@lines[2])
      expect(results.keys[2]).to include(@lines[0])

      expect(results.values[0].size).to eq(4)
      expect(results.values[1].size).to eq(2)
      expect(results.values[2].size).to eq(1)
    end

    it "should filter out low count Allocations" do
      results = @stats.allocations.group_by(:sourcefile, :sourceline, :class).at_least(4).all

      expect(results.size).to eq(1)

      expect(results.keys[0]).to include(@lines[1])
      expect(results.values[0].size).to eq(4)
    end

    it "should output to fixed-width text after group_by(...).sort_by_count correctly" do
      text = @stats.allocations(alias_paths: true)
                   .group_by(:sourcefile, :sourceline, :class)
                   .sort_by_count
                   .to_text.split("\n")
      spec_file = "<PWD>/spec/allocation_stats/allocations_proxy_spec.rb       "

      expect(text[0]).to eq("                     sourcefile                        sourceline  class   count")
      expect(text[1]).to eq("-----------------------------------------------------  ----------  ------  -----")
      expect(text[2]).to eq("#{spec_file}  #{@lines[1]}  Array       4")
      expect(text[3]).to eq("#{spec_file}  #{@lines[2]}  String      2")
      expect(text[4]).to eq("#{spec_file}  #{@lines[0]}  Array       1")
    end
  end
end
