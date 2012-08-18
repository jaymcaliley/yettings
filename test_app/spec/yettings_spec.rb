require 'spec_helper'

describe Yettings do
  YETTINGS_DIR = "#{Rails.root}/config/yettings"
  YETTING_FILE = "#{Rails.root}/config/yetting.yml"
  BLANK_YETTING_FILE = "#{Rails.root}/config/yettings/blank.yml"

  it "should load yettings in the rails app" do
    assert defined?(Yettings)
  end

  describe ".find_yml_files" do
    it "should find only main yml file if no others exist" do
      FileUtils.mv(YETTINGS_DIR,"#{YETTINGS_DIR}_tmp")
      begin
        Yettings.find_yml_files.should eq ["#{Rails.root}/config/yetting.yml"]
      ensure
        FileUtils.mv("#{YETTINGS_DIR}_tmp",YETTINGS_DIR)
      end
    end

    it "should find main and 3 yettings dir files" do
      Yettings.find_yml_files.should eq ["#{Rails.root}/config/yetting.yml",
                                   "#{Rails.root}/config/yettings/blank.yml",
                                   "#{Rails.root}/config/yettings/defaults.yml",
                                   "#{Rails.root}/config/yettings/hendrix.yml",
                                   "#{Rails.root}/config/yettings/jimi.yml"]
    end

    it "should find 3 yettings dir files if there is no main file" do
      FileUtils.mv("#{YETTING_FILE}","#{YETTING_FILE}_tmp")
      begin
        yml_files = Yettings.find_yml_files
        yml_files.should eq ["#{Rails.root}/config/yettings/blank.yml",
                             "#{Rails.root}/config/yettings/defaults.yml",
                             "#{Rails.root}/config/yettings/hendrix.yml",
                             "#{Rails.root}/config/yettings/jimi.yml"]
      ensure
        FileUtils.mv("#{YETTING_FILE}_tmp","#{YETTING_FILE}")
      end
    end
  end

  describe ".load_yml_file" do
    it "should load the yml and return hash" do
      Yettings.load_yml_file("#{YETTING_FILE}").should eq "yetting1"=>"what", "yetting2"=>999, "yetting3"=>"this is erb", "yetting4"=>["element1", "element2"]
    end

    it "should continue gracefully given blank yettings file" do
      Yettings.load_yml_file("#{BLANK_YETTING_FILE}").should == {}
    end

    it "should apply default settings to all environments" do
      hash = Yettings.load_yml_file("#{YETTINGS_DIR}/defaults.yml")
      hash['yetting1'].should eq 'default value'
    end

    it "should override default settings specific to environment" do
      hash = Yettings.load_yml_file("#{YETTINGS_DIR}/defaults.yml")
      hash['yetting2'].should eq 'test value'
    end
  end

  it "should create the classes and class methods" do
    Object.module_eval do
      remove_const :Yetting
    end
    Yettings.create_yetting_class("#{YETTING_FILE}")
    Yetting.yetting1.should eq "what"
    Yetting.yetting2.should eq 999
    Yetting.yetting3.should eq "this is erb"
    Yetting.yetting4.should eq ["element1", "element2"]
  end

  it "should pass the integration test, since rails will run the initializer" do
    Yetting.yetting1.should eq "what"
    JimiYetting.yetting1.should eq "hendrix"
    HendrixYetting.yetting1.should eq "jimi"
  end

  it "should issue a warning for method_missing" do
    begin
      Yetting.whatwhat
    rescue => e
      e.should be_kind_of Yettings::UndefinedYettingError
      e.message.should =~ /whatwhat is not defined in Yetting/
    end
  end

  it "should print the performance of setup method" do
    Object.module_eval do
      remove_const :Yetting
      remove_const :JimiYetting
      remove_const :HendrixYetting
      remove_const :BlankYetting
      remove_const :DefaultsYetting
    end
    start = Time.now
    Yettings.setup!
    puts "Load time for Yettings.setup! = #{Time.now - start} seconds"
  end

  describe ".klass_name" do
    it "should return SomeYetting" do
      Yettings.klass_name("#{YETTINGS_DIR}/some.yml").should eq "SomeYetting"
    end

    it "should raise an error if the class is already defined" do
      AlreadyDefinedConstantYetting = Class.new
      expect { Yettings.klass_name 'already_defined_constant.yml' }.
        to raise_error Yettings::NameConflictError
    end
  end
end
