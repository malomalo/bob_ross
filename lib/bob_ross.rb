require 'singleton'
require 'openssl'

require File.expand_path('../bob_ross/storage', __FILE__)

class BobRoss
  include Singleton
  
  attr_accessor :store, :defaults, :secret_key
  
  def hmac(data)
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret_key, data)
  end
  
  def url(hash, options = {})
    "#{store.host}#{path(hash, options)}"
  end

  def path(hash, options = {})
    options = options.merge(defaults) if defaults
    transforms = encode_transformations(options)
    
    url = options[:format] ? ".#{options[:format]}" : ""
    url = hash + (options[:filename] ? "/#{CGI::escape("#{options[:filename]}")}" : "") + url

    if options[:hmac] && transforms.empty?
      url = "/H#{hmac("/#{url}")}/#{url}"
    elsif options[:hmac]
      url = "#{transforms}/#{url}"
      url = "/H#{hmac(url)}#{url}"
    elsif !transforms.empty?
      url = "/#{transforms}/#{url}"
    else
      url = "/#{url}"
    end
    
    url
  end
  
  def encode_transformations(options)
    string = ""
    options.each do |key, value|
      case key
      when :optimize
        string << 'O'
      when :progressive
        string << 'P'
      when :resize
        string << 'S' << CGI::escape(value).downcase
      when :background
        string << 'B' << value.downcase
      when :expires
        string << 'E' << value.to_i.to_s(16)
      end
    end
    string
  end
  
  # Delegates all uncauge class method calls to the singleton
  def self.method_missing(method, *args, &block)
    instance.__send__(method, *args, &block)
  end
end
