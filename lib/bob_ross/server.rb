require 'cocaine'
require 'mime/types'
require 'sinatra/base'
require 'browser'

jxr = MIME::Type.new('image/jxr')
jxr.extensions.push('jxr')
MIME::Types.add(jxr)

class BobRoss::Server < Sinatra::Base
  
  helpers do
    def extract_options(string)
      transformations = {}
      return transformations unless string
      string.scan(/([A-Z])([^A-Z]*)/) do |key, value|
        case key
        when 'H'
          transformations[:hmac] = value
        when 'O'
          transformations[:optimize] = true
        when 'P'
          transformations[:progressive] = true
        when 'S'
          transformations[:resize] = CGI.unescape(value)
        when 'B'
          transformations[:background] = "##{value}"
        when 'E'
          transformations[:expires] = value.to_i(16)
        end
      end
      transformations
    end
    
    def identify(file)
      command = Cocaine::CommandLine.new("identify", "-verbose :file")
      mime = command.run(file: file.path).match(/^\s+Mime\stype:\s(\S+)\s*$/i)[1]
      MIME::Types[mime].first
    end
    
    def transform(file, transformations, to_format = nil)
      from_format = identify(file)
      to_format ||= from_format
      
      if transformations.empty? && from_format == to_format
        yield file, from_format
      else
        output = Tempfile.new(['blob', ".#{to_format.preferred_extension}"], :binmode => true)
        params = [":input"]
        transformations.each do |key, value|
          case key
          when :background
            params << "-background :background"
          when :optimize
            # params << "-filter Triangle"
            # params << "-define filter:support=2"
            # params << "-unsharp 0.25x0.25+8+0.065"
            # params << "-dither None"
            # params << "-posterize 136"
            params << "-quality 85"
            # params << "-define jpeg:fancy-upsampling=off"
            params << "-define png:compression-filter=5"
            params << "-define png:compression-level=9"
            params << "-define png:compression-strategy=1"
            params << "-define png:exclude-chunk=all"
            params << "-interlace none" unless transformations[:progressive]
            params << "-colorspace sRGB"
            params << "-strip"
          when :progressive
            params << "-interlace Plane"
          when :resize
            params << "-resize :resize"
          end
        end
        params << ":output"
        
        command = Cocaine::CommandLine.new("convert", params.join(' '))
      STDOUT.puts  command.run(transformations.merge(input: file.path, output: output.path))
        command.run(transformations.merge(input: file.path, output: output.path))
        
        yield output, to_format
      end
    end
    
    def valid_hmac?(hmac, using, data)
      using.find do |mtds|
        valid_hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), BobRoss.hmac[:key], mtds.map{ |k| data[k] }.join(''))
        valid_hmac == hmac
      end
    end
  end
  
  get /^\/(?:([A-Z][^\/]*)\/?)?([0-9a-z]+)(?:\/[^\/]+?)?(\.\w+)?$/ do |transformations, hash, format|
    transformations ||= ''
    headers['Cache-Control'] = 'public, max-age=31536000'
    if !format
      headers['Vary'] = 'Accept, User-Agent'
      browser = Browser.new(:ua => request.user_agent, :accept_language => headers["HTTP_ACCEPT_LANGUAGE"])
      format = if request.accept.include?('image/webp')
        MIME::Types['image/webp']
      elsif (browser.ie? && browser.version.to_f > 9) || browser.edge? || (browser.ie? && browser.mobile?)
        MIME::Types['image/jxr']
      else
        MIME::Types['image/jpeg']
      end
    else
      format = MIME::Types.of(format).first
    end
    
    if BobRoss.hmac[:required] || (transformations && transformations.start_with?('H'))
      if match = transformations.match(/^H([^A-Z]+)(.*)$/)
        provided_hmac = match[1]
        transformation_data = match[2]
        
        if !valid_hmac?(provided_hmac, BobRoss.hmac[:methods], {transformations: transformation_data, hash: hash, format: format})
          not_found
        end
      else
        not_found
      end
    end

    transformations = extract_options(transformations)
    original_file = if BobRoss.store.local?
      File.open(BobRoss.store.destination(hash))
    else
      BobRoss.store.copy_to_tempfile(hash)
    end
    
    transform(original_file, transformations, format) do |output, mime|
      
      # set cache, expires...
      # Cache-Control:public
      # Expires: Mon, 25 Jun 2012 21:31:12 GMT

      if output.is_a?(Tempfile)
        headers['Content-Type'] = mime.to_s
        output
      else
        send_file output.path, type: mime.to_s
      end
    end
  end

end