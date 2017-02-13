require 'singleton'
require 'openssl'
require 'cgi'

require File.expand_path('../bob_ross/storage', __FILE__)

class BobRoss
  include Singleton
  
  attr_accessor :defaults
  
  def url(hash, options = {})
    options = defaults.merge(options) if defaults
    "#{options[:host]}#{path(hash, options)}"
  end

  def path(hash, options = {})
    options = defaults.merge(options) if defaults
    
    transforms = encode_transformations(options)
    
    url = options[:format] ? ".#{options[:format]}" : ""
    url = hash + (options[:filename] ? "/#{CGI::escape("#{options[:filename]}")}" : "") + url

    if options[:hmac]
      hmac_data = ''
      
      if options[:hmac].is_a?(String)
        options[:hmac] = { key: options[:hmac] }
      end
      options[:hmac] = defaults[:hmac].merge(options[:hmac]) if defaults && defaults[:hmac]
      
      if !options[:hmac].has_key?(:attributes)
        options[:hmac][:attributes] = [:transformations, :hash]
      end

      options[:hmac][:attributes].each do |attr|
        case attr
        when :hash
          hmac_data << hash
        when :transformations
          hmac_data << transforms
        when :format
          hmac_data << options[:format].to_s
        end
      end
      
      hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), options[:hmac][:key], hmac_data)
      transforms = "H#{hmac}#{transforms}"
    end
    
    if !transforms.empty?
      "/#{CGI::escape(transforms)}/#{url}"
    else
      "/#{url}"
    end
  end

  def encode_transformations(options)
    string = []
    options.each do |key, value|
      case key
      when :background
        string << 'B' + value.downcase
      when :expires
        string << 'E' + value.to_i.to_s(16)
      when :grayscale
        string << 'G'
      when :lossless
        string << 'L'
      when :optimize
        string << 'O'
      when :progressive
        string << 'P'
      when :resize
        string << 'S' + value.downcase
      when :watermark
        string << if value.is_a?(Integer)
          'W' + value.to_s + 'se'
        else
          'W' + (value[:id] || 0).to_s + (value[:position] || 'se') + value[:offset].to_s if value
        end
      # when :quality
      #   string << "Q#{value}"
      end
    end
    
    string.sort.join('')
  end
  
  # Delegates all uncauge class method calls to the singleton
  def self.method_missing(method, *args, &block)
    instance.__send__(method, *args, &block)
  end
end