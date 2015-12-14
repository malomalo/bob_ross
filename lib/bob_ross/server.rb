require 'cocaine'
require 'mime/types'
require 'sinatra/base'

jxr = MIME::Type.new('image/vnd.ms-photo')
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
        when 'W'
          transformations[:watermark] = value
        when 'L'
          transformations[:lossless] = true
        when 'T'
          transformations[:transparent] = true
        end
      end
      transformations
    end
    
    def identify(file)
      command = Cocaine::CommandLine.new("identify", "-verbose :file")
      output = command.run(file: file.path)
      {
        mime: MIME::Types[output.match(/^\s+Mime\stype:\s(\S+)\s*$/i)[1]].first,
        geo: parse_geometry(output.match(/^\s+Geometry:\s([0-9x\-\+]+)\s*$/i)[1])
      }
    end
    
    def parse_geometry(string)
      string =~ /^(\d+)?(x(\d+))?([+-]\d+)?([+-]\d+)?.*$/
      
      {
        width: $1.to_i,
        height: $3.to_i,
        x_offset: $4.to_i,
        y_offset: $5.to_i
      }
    end
    
    def transform(file, transformations, to_format = nil)
      info = identify(file)
      from_format = info[:mime]
      to_format ||= from_format
      
      if transformations.empty? && from_format == to_format
        yield file, from_format
      else
        output = Tempfile.new(['blob', ".#{to_format.preferred_extension}"], :binmode => true)
        params = []
        
        transformations[:background] ||= '#00000000'
        params << "-background :background"

        params << "\\(" << ":input"
        params << "-resize :resize" if transformations[:resize]
        params << "\\)"
        
        if transformations[:watermark] =~ /^(\d+)(\w{2})(.*)$/i
          transformations[:watermark_file] = BobRoss.watermarks[$1.to_i]
          transformations[:watermark_geometry] = $3
          transformations[:watermark_postion] = $2.sub('n', 'North').sub('e', 'East').sub('s', 'South').sub('w', 'West')

          if !(transformations[:watermark_geometry] =~ /[\-\+]\d+$/)
            transformations[:watermark_geometry] += "+0"
          end
          
          geo = parse_geometry(transformations[:watermark_geometry])
          output_size = if transformations[:resize]
            parse_geometry(transformations[:resize])
          else
            info[:geo]
          end
          
          if output_size[:width] > geo[:width] * 2 && output_size[:height] > geo[:height] * 2
            params << ":watermark_file -gravity :watermark_postion -geometry :watermark_geometry -composite"
          end
        end
        
        if transformations[:resize] && transformations[:resize].end_with?('#')
          params << "-gravity center -extent :extent"
          transformations[:extent] = transformations[:resize][0..-2]
          transformations[:resize] = transformations[:resize][0..-2]
        end
          
        transformations.each do |key, value|
          case key
          when :lossless
            params << "-define webp:lossless=true"
          when :optimize
            params << "-quality 85" unless to_format.to_s == 'image/webp'
            params << "-define png:compression-filter=5"
            params << "-define png:compression-level=9"
            params << "-define png:compression-strategy=1"
            params << "-define png:exclude-chunk=all"
            params << "-interlace none" unless transformations[:progressive]
            params << "-colorspace sRGB"
            params << "-strip"
          when :progressive
            params << "-interlace Plane"
          end
        end
        transformations.delete(:lossless)
        
        params << ":output"
        
        command = Cocaine::CommandLine.new("convert", params.join(' '))
        puts command.command(transformations.merge(input: file.path, output: output.path))
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
    
    def accept?(mime)
      request.env['HTTP_ACCEPT'] && request.env['HTTP_ACCEPT'].include?(mime)
    end
  end
  
  get /^\/(?:([A-Z][^\/]*)\/?)?([0-9a-z]+)(?:\/[^\/]+?)?(\.\w+)?$/ do |transformation_string, hash, format|
    transformation_string ||= ''
    transformations = extract_options(transformation_string)
    
    if !format
      headers['Vary'] = 'Accept'
      
      format = if accept?('image/webp')
        MIME::Types['image/webp'].first
      elsif accept?('image/jxr')
        MIME::Types['image/vnd.ms-photo'].first
      else
        transformations[:transparent] ? MIME::Types['image/png'].first : MIME::Types['image/jpeg'].first
      end
    else
      format = MIME::Types.of(format).first
    end
    
    if BobRoss.hmac[:required] || (transformation_string && transformation_string.start_with?('H'))
      if match = transformation_string.match(/^H([^A-Z]+)(.*)$/)
        provided_hmac = match[1]
        transformation_data = match[2]
        
        if !valid_hmac?(provided_hmac, BobRoss.hmac[:methods], {transformations: transformation_data, hash: hash, format: format})
          not_found
        end
      else
        not_found
      end
    end

    
    original_file = if BobRoss.store.local?
      File.open(BobRoss.store.destination(hash))
    else
      BobRoss.store.copy_to_tempfile(hash)
    end
    
    transform(original_file, transformations, format) do |output, mime|
      # Do this at the end to not cache errors
      headers['Cache-Control'] = 'public, max-age=31536000'
      if output.is_a?(Tempfile)
        headers['Content-Type'] = mime.to_s
        output
      else
        send_file output.path, type: mime.to_s
      end
    end
  end

end