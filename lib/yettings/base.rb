require 'yaml'
require 'erb'
require 'openssl'

class Yettings::Base
  class UndefinedYettingError < StandardError; end

  def self.method_missing(method_id, *args)
    raise UndefinedYettingError, "#{method_id} is not defined in #{self}"
  end

  def self.[](key)
    send key
  end

  def self.load_yml_erb(yml_erb)
    yml = ERB.new(yml_erb).result
    full_hash = build_hash yml
    defaults = full_hash.delete('defaults') || {}
    env_hash = full_hash[Rails.env] || {}
    define_methods defaults.merge(env_hash)
  end

  def self.define_methods(hash)
    hash.each do |key, value|
      class_attribute key
      if value.is_a? Hash
        send "#{key}=", Class.new(Yettings::Base)
        send(key).define_methods(value)
      else
        define_singleton_method(key) { value }
      end
    end
  end

  def self.build_hash(yml)
    yml.present? ? YAML.load(yml).to_hash : {}
  end
end
