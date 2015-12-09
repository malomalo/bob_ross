require 'singleton'
require 'openssl'

require File.expand_path('../bob_ross/storage', __FILE__)

class BobRoss
  include Singleton
  
  attr_accessor :store, :host, :hmac, :defaults, :watermarks
  
  def calculate_hmac(data)
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), hmac[:key], data)
  end
  
  def url(hash, options = {})
    "#{host}#{path(hash, options)}"
  end

  def path(hash, options = {})
    options = defaults.merge(options) if defaults
    transforms = encode_transformations(options)
    
    url = options[:format] ? ".#{options[:format]}" : ""
    url = hash + (options[:filename] ? "/#{CGI::escape("#{options[:filename]}")}" : "") + url

    if options[:hmac]
      hmac_data = ''
      options[:hmac] = [:transformations, :hash] if options[:hmac] == true
      options[:hmac].each do |mtd|
        case mtd
        when :hash
          hmac_data << hash
        when :transformations
          hmac_data << transforms
        when :format
          hmac_data << options[:format].to_s
        end
      end
      
      transforms = "H#{calculate_hmac(hmac_data)}#{transforms}"
    end
    
    if !transforms.empty?
      "/#{transforms}/#{url}"
    else
      "/#{url}"
    end
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
      when :watermark
        string << 'W' + (value[:id] || 0) + (value[:position] || 'se') + (value[:offset] || '+5+5')
      when :lossless
        string << 'L'
      # when :quality
      #   string << "Q#{value}"
      end
    end
    string
  end
  
  # Delegates all uncauge class method calls to the singleton
  def self.method_missing(method, *args, &block)
    instance.__send__(method, *args, &block)
  end
end

# hmac = {
#  key: secret key used for hmac
#  methods [[], [:hash], [:transforms], [:hash, :transforms]]
#}