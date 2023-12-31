require "./spec_helper"

require "../src/quantity"

module Quantity
  it "rounds up to 1 GB" do
    estimate_gb("123").should eq 1
  end

  it "works with bytes" do
    estimate_gb("123456789").should eq 1
  end

  it "works with k bytes" do
    estimate_gb("123000000k").should eq 123
  end

  it "works with Ki bytes" do
    estimate_gb("124000000Ki").should eq 124
  end

  it "works with M bytes" do
    estimate_gb("125000M").should eq 125
  end

  it "works with Mi bytes" do
    estimate_gb("126000Mi").should eq 126
  end

  it "works with G bytes" do
    estimate_gb("127G").should eq 127
  end

  it "works with Gi bytes" do
    estimate_gb("128Gi").should eq 128
  end

  it "works with Floats" do
    estimate_gb("129000000000.123").should eq 129
  end

  it "works with scientific Floats" do
    estimate_gb("1.3e5Mi").should eq 130
  end
end
