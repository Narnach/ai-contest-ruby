require 'spec_helper'
require 'core_ext'

describe "Array#last_match" do
  it "should find the last matching item" do
    [1,2,3,4,5].last_match {|e| e < 3}.should == 2
  end
end

describe "Array#sum" do
  it "should add up integers" do
    [1,2,3,4].sum.should == 10
  end
end
