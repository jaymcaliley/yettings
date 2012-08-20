require 'yaml'
require 'erb'
require 'openssl'
YETTINGS_PATH = "#{File.dirname(__FILE__)}/yettings"
require "#{YETTINGS_PATH}/railtie.rb"
require "#{YETTINGS_PATH}/base.rb"

module Yettings
  class UndefinedYettingError < StandardError; end
  class NameConflictError < StandardError; end
  class << self
    def setup!
      encrypt_files!
      decrypt_files!
      (find_yml_files + find_private_yml_files).each do |yml_file|
        create_yetting_class yml_file
      end
    end

    def create_yetting_class(yml_file)
      name = klass_name(yml_file)
      klass = Object.const_set klass_name(yml_file), Class.new(Yettings::Base)
      klass.load_yml_erb File.read(yml_file)
    end

    def klass_name(yml_file)
      basename = File.basename(yml_file)
      if basename == "yetting.yml"
        name = "Yetting"
      else
        name = basename.gsub(/\.pub$/,"").gsub(/\.yml$/,"").camelize + "Yetting"
      end
      return name unless Object.const_defined?(name)
      if name.constantize.ancestors.include? Yettings::Base
        Object.module_eval { remove_const name }.to_s
      else
        raise NameConflictError, "#{name} is already defined"
      end
    end

    def rails_config
      "#{Rails.root}/config"
    end

    def root
      "#{rails_config}/yettings"
    end

    def private_root
      "#{root}/\.private"
    end

    def find_yml_files
      Dir.glob("#{rails_config}/yetting.yml") + Dir.glob("#{root}/**/*.yml")
    end

    def find_public_yml_files
      Dir.glob("#{root}/**/*.yml.pub")
    end

    def find_private_yml_files
      Dir.glob("#{private_root}/**/*.yml")
    end

    def decrypt_yml(yml)
      hash = yml.present? ? YAML.load(yml).to_hash : {}
      decrypt_hash(hash).to_yaml
    end

    def encrypt_yml(yml)
      hash = yml.present? ? YAML.load(yml).to_hash : {}
      encrypt_hash(hash).to_yaml
    end

    def decrypt_hash(public_hash)
      public_hash.inject({}) do |private_hash, key_val|
        key, val = key_val
        private_hash.update key => decrypt(val) # recursive!
      end
    end

    def encrypt_hash(private_hash)
      private_hash.inject({}) do |public_hash, key_val|
        key, val = key_val
        public_hash.update key => encrypt(val) # recursive!
      end
    end

    def decrypt(obj)
      obj.is_a?(Hash) ? decrypt_hash(obj) : decrypt_string(obj.to_s)
    end

    def encrypt(obj)
      obj.is_a?(Hash) ? encrypt_hash(obj) : encrypt_string(obj.to_s)
    end

    def decrypt_string(public_string)
      if private_key.present?
        private_key.private_decrypt(public_string).to_s.force_encoding("UTF-8")
      else
        "access denied (no private key found)"
      end
    end

    def encrypt_string(private_string)
      public_key.public_encrypt(private_string).to_s
    end

    def encrypt_file(private_file)
      public_file = public_path(private_file)
      public_yml = encrypt_yml File.read(private_file)
      return if private_key.nil? # Don't overwrite encrypted file without key
      return unless check_overwrite(public_file, private_file, public_yml)
      File.open(public_file, 'w') { |f| f.write public_yml }
    end

    def encrypt_files!
      find_private_yml_files.each do |yml_file|
        encrypt_file yml_file
      end
    end

    def decrypt_file(public_file)
      private_file = private_path(public_file)
      private_yml = decrypt_yml File.read(public_file)
      return unless check_overwrite(private_file, public_file, private_yml)
      File.open(private_file, 'w') { |f| f.write private_yml }
    end

    def decrypt_files!
      find_public_yml_files.each do |yml_file|
        decrypt_file yml_file
      end
    end

    def private_path(path)
      path.gsub(/^#{root}/, "#{private_root}").gsub(/.pub$/, "")
    end

    def public_path(path)
      path.gsub(/^#{private_root}/, root) + '.pub'
    end

    def check_overwrite(dest, source, content)
      unless File.exists?(dest)
        STDERR.puts "WARNING: creating #{dest} with contents of #{source}"
        return true
      end
      return false if File.read(dest) == content
      if File.mtime(source) > File.mtime(dest)
        STDERR.puts "WARNING: overwriting #{dest} with contents of #{source}"
        true
      else
        false
      end
    end

    def public_key
      @public_key ||= load_key :public
    end

    def private_key
      @private_key ||= load_key :private
    end

    def load_key(type)
      key_file = key_path(type)
      if File.exists?(key_file)
        key = OpenSSL::PKey::RSA.new File.read(key_file)
        message = "Key #{key_file} is not a #{type} key"
        raise RuntimeError, message unless key.send "#{type}?"
        key
      end
    end

    def key_path(type)
      ENV["YETTINGS_#{type.to_s.upcase}_KEY"] || "#{root}/.#{type}_key"
    end

    def gen_keys
      key = OpenSSL::PKey::RSA.new 2048

      private_path = "#{root}/.private"
      FileUtils.mkpath private_path

      private_file = "#{root}/.private_key"
      File.open(private_file, 'w') { |f| f.write key.to_pem }

      public_file = "#{root}/.public_key"
      File.open(public_file, 'w') { |f| f.write key.public_key.to_pem }

      gitignore = "#{root}/.gitignore"
      File.open(gitignore, 'a') do |f|
        f.puts ".private_key"
        f.puts ".private"
      end
    end

  end # class << self
end
