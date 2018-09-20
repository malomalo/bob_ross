require 'singleton'
require 'openssl'
require 'cgi'

require File.expand_path('../bob_ross/storage', __FILE__)

class BobRoss
  include Singleton
  
  attr_reader :defaults
  
  def defaults=(d)
    @defaults = normalize_options(d)
  end
  
  def normalize_options(options)
    if options.has_key?(:hmac)
      options[:hmac] = { key: options[:hmac] } if options[:hmac].is_a?(String)

      if !options[:hmac].has_key?(:attributes)
        options[:hmac][:attributes] = [:transformations, :hash]
      elsif options[:hmac][:attributes].first.is_a?(Array)
        options[:hmac][:attributes] = options[:hmac][:attributes].first
      end
    end

    options
  end
  
  def url(hash, options = {})
    "#{options[:host] || defaults[:host]}#{path(hash, options)}"
  end

  def path(hash, options = {})
    options = defaults.merge(options) if defaults
    options = normalize_options(options)
    
    transforms = encode_transformations(options)
    
    url = options[:format] ? ".#{options[:format]}" : ""
    url = hash + (options[:filename] ? "/#{CGI::escape("#{options[:filename]}")}" : "") + url

    if options[:hmac]
      hmac_data = ''

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
      when :crop
        string << 'C' + value.downcase
      when :expires
        string << 'E' + value.to_i.to_s(16)
      when :grayscale
        string << 'G'
      when :interlace
        string << 'I'
      when :lossless
        string << 'L'
      when :optimize
        string << 'O'
      when :padding
        string << 'P' + value.join(',')
      when :resize
        string << 'S' + value.downcase
      when :watermark
        if value.is_a?(Integer)
          string << 'W' + value.to_s + 'se'
        elsif value
          string << 'W' + (value[:id] || 0).to_s + (value[:position] || 'se') + value[:offset].to_s
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

require 'bob_ross/railtie' if defined?(Rails)