require 'cocaine'
require 'mime/types'
require 'bob_ross/image'

# When we support jxr
# if MIME::Types['image/vnd.ms-photo'].empty?
#   jxr = MIME::Type.new('image/vnd.ms-photo')
#   jxr.extensions.push('jxr')
#   MIME::Types.add(jxr)
# else
#   MIME::Types['image/vnd.ms-photo'].first.preferred_extension = 'jxr'
# end


class BobRoss::Server
  
  class StreamFile
    def initialize(file)
      @file = File.open(file.path)
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
  
  attr_accessor :settings
  
  def initialize(settings={})
    @settings = settings
  end
  
  def call(env)
    path = ::URI::DEFAULT_PARSER.unescape(env['PATH_INFO'])
    match = path.match(/^\/(?:([A-Z][^\/]*)\/?)?([0-9a-z]+)(?:\/[^\/]+?)?(\.\w+)?$/)
    
    return not_found if !match

    response_headers = {}
    
    transformation_string = match[1] || ''
    hash = match[2]
    requested_format = match[3]

    if transformation_string && transformation_string.start_with?('H')
      match = transformation_string.match(/^H([^A-Z]+)(.*)$/)
      provided_hmac = match[1]
      transformation_data = match[2]
      
      if !valid_hmac?(provided_hmac, @settings[:hmac][:attributes], {
        transformations: transformation_data,
        hash: hash,
        format: requested_format
      })
        return not_found
      end
    elsif @settings.dig(:hmac, :required)
      return not_found 
    end
    
    transformations = extract_options(transformation_string)
    
    last_modified = @settings[:store].last_modified(hash)
    if env['HTTP_IF_MODIFIED_SINCE']
      modified_since_time = Time.httpdate(env['HTTP_IF_MODIFIED_SINCE'])
      return not_modified if last_modified < modified_since_time
    end
    response_headers['Last-Modified'] = last_modified.httpdate

    if env['HTTP_DPR'] && transformations[:resize]
      transformations[:dpr] = env['HTTP_DPR'].to_f
      transformations[:resize] = transformations[:resize].gsub(/\d+/){ |d| d.to_i * transformations[:dpr] }
      response_headers['Content-DPR'] = transformations[:dpr].to_s
    end

    if requested_format
      transformations[:format] = MIME::Types.of(requested_format).first
    end
    
    if transformations[:format]
      if transformations[:resize]
        response_headers['Vary'] = 'DPR'
      end
    else
      if transformations[:resize]
        response_headers['Vary'] = 'Accept, DPR'
      else
        response_headers['Vary'] = 'Accept'
      end
    end
    
    original_file = if @settings[:store].local?
      File.open(@settings[:store].destination(hash))
    else
      @settings[:store].copy_to_tempfile(hash)
    end
    
    image = BobRoss::Image.new(original_file, @settings)
    if !transformations[:format]
      choices = ['image/webp', 'image/jpeg', 'image/png']
      
      if image.transparent || transformations[:transparent]
        choices.delete('image/jpeg')
      end
      
      if !accept?(env, 'image/webp')
        choices.delete('image/webp')
      end
      
      transformations[:format] = MIME::Types[choices.first].first
    end
    
    transformed_file = image.transform(transformations)
    
    # Do this at the end to not cache errors
    response_headers['Content-Type'] = transformations[:format].to_s
    response_headers['Cache-Control'] = @settings[:cache_control]
    
    [200, response_headers, StreamFile.new(transformed_file)]
  ensure
    if original_file
      original_file.is_a?(Tempfile) ? original_file.close! : original_file.close
    end
  end
  
  private
  
  def not_modified
    [304, {}, []]
  end
  
  def not_found
    [404, {"Content-Type" => "text/plain"}, ["404 Not Found"]]
  end
  
  def extract_options(string)
    transformations = {}
    return transformations unless string
    
    string.scan(/([A-Z])([^A-Z]*)/) do |key, value|
      case key
      when 'B'.freeze
        transformations[:background] = "##{value}"
      when 'E'.freeze
        transformations[:expires] = value.to_i(16)
      when 'G'.freeze
        transformations[:grayscale] = true
      when 'H'.freeze
        transformations[:hmac] = value
      when 'L'.freeze
        transformations[:lossless] = true
      when 'O'.freeze
        transformations[:optimize] = true
      when 'P'.freeze
        transformations[:progressive] = true
      when 'S'.freeze
        transformations[:resize] = CGI.unescape(value)
      when 'T'.freeze
        transformations[:transparent] = true
      when 'W'.freeze
        transformations[:watermark] = value
      end
    end
    transformations
  end
  
  def valid_hmac?(hmac, using, data)
    using.find do |mtds|
      valid_hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), @settings[:hmac][:key], mtds.map{ |k| data[k] }.join(''))
      valid_hmac == hmac
    end
  end
  
  def accept?(env, mime)
    env['HTTP_ACCEPT'] && env['HTTP_ACCEPT'].include?(mime)
  end
  
end
