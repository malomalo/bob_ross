require 'cocaine'
require 'mime/types'

if MIME::Types['image/vnd.ms-photo'].empty?
  jxr = MIME::Type.new('image/vnd.ms-photo')
  jxr.extensions.push('jxr')
  MIME::Types.add(jxr)
end

class BobRoss::Server
  
  class StreamFile
    def initialize(file)
      @file = file
    end
    
    def each
      @file.seek(0)
      while part = @file.read(8192)
        yield part
      end
    ensure
      @file.is_a?(Tempfile) ? @file.close! : @file.close
    end
  end
  
  def not_found
    [404, {"Content-Type" => "text/plain"}, ["404 Not Found"]]
  end
  
  def call(env)
    path = ::URI::DEFAULT_PARSER.unescape(env['PATH_INFO'])
    match = path.match(/^\/(?:([A-Z][^\/]*)\/?)?([0-9a-z]+)(?:\/[^\/]+?)?(\.\w+)?$/)
    
    return not_found if !match
    
    response_headers = {}
    
    transformation_string = match[1] || ''
    hash = match[2]
    format = match[3]
    transformations = extract_options(transformation_string)

    if BobRoss.hmac[:required] || (transformation_string && transformation_string.start_with?('H'))
      if match = transformation_string.match(/^H([^A-Z]+)(.*)$/)
        provided_hmac = match[1]
        transformation_data = match[2]
      
        if !valid_hmac?(provided_hmac, BobRoss.hmac[:methods], {transformations: transformation_data, hash: hash, format: format})
          return not_found
        end
      else
        return not_found
      end
    end
    
    last_modified = BobRoss.store.last_modified(hash)
    if env['HTTP_IF_MODIFIED_SINCE']
      modified_since_time = Time.httpdate(env['HTTP_IF_MODIFIED_SINCE'])
      return [304, response_headers, []] if last_modified < modified_since_time
    end
    response_headers['Last-Modified'] = last_modified.httpdate
    
    if !format
      response_headers['Vary'] = 'Accept'
      
      format = if accept?(env, 'image/webp')
        MIME::Types['image/webp'].first
      elsif accept?(env, 'image/jxr')
        MIME::Types['image/vnd.ms-photo'].first
      else
        transformations[:transparent] ? MIME::Types['image/png'].first : MIME::Types['image/jpeg'].first
      end
    else
      format = MIME::Types.of(format).first
    end
    
    
    
    original_file = if BobRoss.store.local?
      File.open(BobRoss.store.destination(hash))
    else
      BobRoss.store.copy_to_tempfile(hash)
    end
    transformed_file = transform(original_file, transformations, format)
    
    # Do this at the end to not cache errors
    response_headers['Content-Type'] = format.to_s
    response_headers['Cache-Control'] = 'public, max-age=31536000'
    
    if original_file != transformed_file
      original_file.is_a?(Tempfile) ? original_file.close! : original_file.close
    end
    
    [200, response_headers, StreamFile.new(transformed_file)]

  end
  
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
      when 'G'
        transformations[:grayscale] = true
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
    string =~ /^(\d+)?(?:x(\d+))?([+-]\d+)?([+-]\d+)?.*$/
    
    {
      width: $1 ? $1.to_i : nil,
      height: $2 ? $2.to_i : nil,
      x_offset: $3 ? $3.to_i : nil,
      y_offset: $4 ? $4.to_i : nil
    }
  end
  
  def transform(file, transformations, to_format = nil)
    info = identify(file)
    from_format = info[:mime]
    to_format ||= from_format
    
    if transformations.empty? && from_format == to_format
      file
    else
      output = Tempfile.new(['blob', ".#{to_format.preferred_extension}"], :binmode => true)
      params = []
      
      transformations[:background] ||= '#00000000'
      params << "-background :background"

      params << "\\(" << ":input"
      if transformations[:resize]
        params << "-resize :resize"
        if transformations[:resize].end_with?('*')
          params << "-gravity center -crop :crop"
          transformations[:crop] = transformations[:resize][0..-2] + "+0+0"
          transformations[:resize] = transformations[:resize][0..-2] + "^"
        end
      end
      
      params << "-alpha remove" if transformations[:background]
      params << "\\)"
      
      if transformations[:watermark] =~ /^(\d+)(\w{2})(.*)$/i
        transformations[:watermark_file] = BobRoss.watermarks[$1.to_i]
        transformations[:watermark_geometry] = $3
        transformations[:watermark_postion] = $2.sub('n', 'North').sub('e', 'East').sub('s', 'South').sub('w', 'West')
        
        geo = parse_geometry(transformations[:watermark_geometry])
        output_size = if transformations[:resize]
          parse_geometry(transformations[:resize])
        else
          info[:geo]
        end
        
        if !geo[:width] && !geo[:height]
          if output_size[:width] * output_size[:height] <= 60_000
            geo[:width] = ([output_size[:width], output_size[:height]].max * 0.10).floor
            geo[:height] = geo[:width]
          elsif output_size[:width] * output_size[:height] <= 90_000
            geo[:width] = ([output_size[:width], output_size[:height]].max * 0.08).floor
            geo[:height] = geo[:width]
          else
            geo[:width] = ([output_size[:width], output_size[:height]].max * 0.05).floor
            geo[:height] = geo[:width]
          end
        end
        
        if !geo[:x_offset] && !geo[:y_offset]
          geo[:x_offset] = (geo[:width] / 2.0).ceil
          geo[:y_offset] = geo[:x_offset]
        end
        
        transformations[:watermark_geometry] = "#{geo[:width]}x#{geo[:height]}+#{geo[:x_offset]}+#{geo[:x_offset]}"
        
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
        when :grayscale
          params << "-colorspace gray"
        end
      end
      transformations.delete(:lossless)
      
      params << ":output"
      
      command = Cocaine::CommandLine.new("convert", params.join(' '))
      command.run(transformations.merge(input: file.path, output: output.path))
      
      output
    end
  end
  
  def valid_hmac?(hmac, using, data)
    using.find do |mtds|
      valid_hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), BobRoss.hmac[:key], mtds.map{ |k| data[k] }.join(''))
      valid_hmac == hmac
    end
  end
  
  def accept?(env, mime)
    env['HTTP_ACCEPT'] && env['HTTP_ACCEPT'].include?(mime)
  end

end