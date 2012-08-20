require 'spec_helper'

describe Yettings::Base do
  YETTINGS_DIR = "#{Rails.root}/config/yettings"
  YETTING_FILE = "#{Rails.root}/config/yetting.yml"
  BLANK_YETTING_FILE = "#{Rails.root}/config/yettings/blank.yml"

  subject { Class.new Yettings::Base }

  describe ".load_yml_erb" do

    it "should load the yml and return hash" do
      yml_erb = File.read YETTING_FILE
      expected = {"yetting1" => "what",
                  "yetting2" => 999,
                  "yetting3" => "this is erb",
                  "yetting4" => ["element1", "element2"]}
      subject.load_yml_erb(yml_erb).should eq expected
    end

    it "should continue gracefully given blank yettings file" do
      subject.should_receive(:define_methods).with({})
      yml_erb = File.read BLANK_YETTING_FILE
      subject.load_yml_erb(yml_erb)
    end

    it "should apply default settings to all environments" do
      yml_erb = File.read "#{YETTINGS_DIR}/defaults.yml"
      subject.load_yml_erb(yml_erb)
      subject.yetting1.should eq 'default value'
    end

    it "should override default settings specific to environment" do
      yml_erb = File.read "#{YETTINGS_DIR}/defaults.yml"
      subject.load_yml_erb(yml_erb)
      subject.yetting2.should eq 'test value'
    end
  end

  it "should issue a warning for method_missing" do
    begin
      subject.whatwhat
    rescue => e
      e.should be_kind_of Yettings::Base::UndefinedYettingError
      e.message.should =~ /whatwhat is not defined in /
    end
  end

end
