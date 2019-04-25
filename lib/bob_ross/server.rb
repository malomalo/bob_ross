require 'terrapin'
require 'mini_mime'
require 'bob_ross/image'
require 'bob_ross/log_subscriber'

# When we support jxr
# if MIME::Types['image/vnd.ms-photo'].empty?
#   jxr = MIME::Type.new('image/vnd.ms-photo')
#   jxr.extensions.push('jxr')
#   MIME::Types.add(jxr)
# else
#   MIME::Types['image/vnd.ms-photo'].first.preferred_extension = 'jxr'
# end


class BobRoss::Server
  
  SUPPORTED_FORMATS = ["image/webp", "image/jpeg", "image/png"]

  class StreamFile
    def initialize(file)
      @file = File.open(file.path)
    end
    
    def each
      @file.seek(0)
      while part = @file.read(16_384)
        yield part
      end
    ensure
      @file.is_a?(Tempfile) ? @file.close! : @file.close
    end
  end
  
  attr_accessor :settings, :palette, :logger
  
  def initialize(settings={})
    @settings = normalize_options(settings)
    @palette = @settings[:palette]
    @settings[:last_modified_header] = false unless @settings.has_key?(:last_modified_header)
    @logger = (@settings.has_key?(:logger) ? @settings.delete(:logger) : Logger.new(STDOUT))
  end
  
  def normalize_options(options)
    result = options.dup
    result.delete(:hmac)
    
    if options[:hmac].is_a?(String)
      result[:hmac] = { key: options[:hmac], required: true, attributes: [[:transformations, :hash]] }
    elsif options[:hmac]
      result[:hmac] = { key: options[:hmac][:key] }
      
      if options[:hmac][:attributes]
        if options[:hmac][:attributes].first.is_a?(Array)
          result[:hmac][:attributes] = options[:hmac][:attributes].map{ |a| a.map(&:to_sym) }
        else
          result[:hmac][:attributes] = [options[:hmac][:attributes].map(&:to_sym)]
        end
      else
        result[:hmac][:attributes] = [[:transformations, :hash]]
      end
      
      if options[:hmac][:transformations] && options[:hmac][:transformations][:optional]
        ignorable_transformations = if options[:hmac][:transformations][:optional].is_a?(Array)
          options[:hmac][:transformations][:optional]
        else
          [ options[:hmac][:transformations][:optional] ]
        end
        ignorable_transformations.map! { |t| BobRoss.transformations[t.to_sym] }
        
        result[:hmac][:transformations] = { optional: [] }
        ignorable_transformations.size.times do |i|
          ignorable_transformations.permutation(i+1).each do |pm|
            result[:hmac][:transformations][:optional] << pm
          end
        end
      end

      result[:hmac][:required] = (options.has_key?(:required) ? options[:required] : true)
    end
    
    if options[:palette] && options[:palette].is_a?(Hash) && !options[:palette].empty?
      require 'bob_ross/palette'
      result[:palette] = BobRoss::Palette.new(
        options[:palette][:path],
        options[:palette][:file],
        size: options[:palette][:size]
      )
    end
    
    if options[:watermarks]
      options[:watermarks].map! do |watermark_path|
        {
          path: watermark_path,
          geometry: BobRoss.backend.identify(watermark_path)[:geometry]
        }
      end
    end

    result
  end
  
  def call(env)
    ActiveSupport::Notifications.instrument("start_processing.bob_ross")
    
    ActiveSupport::Notifications.instrument("process.bob_ross") do |payload|
      path = ::URI::DEFAULT_PARSER.unescape(env['PATH_INFO']).force_encoding('UTF-8')
      match = path.match(/\A\/(?:([A-Z][^\/]*)\/?)?([0-9a-z\-]+)(?:\/[^\/]+?)?(\.\w+)?\Z/)
    
      if !match
        payload[:status] = 404
        return not_found
      end

      response_headers = {}
    
      transformation_string = match[1] || ''
      hash = match[2]
      requested_format = match[3]
      
      if transformation_string.start_with?('H')
        match = transformation_string.match(/^H([^A-Z]+)(.*)$/)
        provided_hmac = match[1]
        transformation_string = match[2]
      
        if !valid_hmac?(provided_hmac, {
          transformations: transformation_string,
          hash: hash,
          format: requested_format
        })
          payload[:status] = 404
          return not_found
        end
      elsif @settings.dig(:hmac, :required)
        payload[:status] = 404
        return not_found 
      end
      
      options, transformations = extract_options(transformation_string)
      
      if options[:expires]
        if options[:expires] <= Time.now
          ActiveSupport::Notifications.instrument("expired.bob_ross", {
            expired_at: options[:expires]
          })
          payload[:status] = 410
          return gone
        end

        transformation_string.gsub!(/E([^A-Z]+)/, '') # Remove Expires for cache
      end
      
      if @settings[:last_modified_header]
        last_modified = @settings[:store].last_modified(hash)
        if env['HTTP_IF_MODIFIED_SINCE']
          modified_since_time = Time.httpdate(env['HTTP_IF_MODIFIED_SINCE'])
          payload[:status] = 304
          return not_modified if last_modified <= modified_since_time
        end
        response_headers['Last-Modified'] = last_modified.httpdate
      end

      if requested_format
        options[:format] = MiniMime.lookup_by_extension(requested_format.delete_prefix('.')).content_type
      end
    
      if options[:format].nil?
        response_headers['Vary'] = 'Accept'
      end

      if accepts = env['HTTP_ACCEPT']
        accepts = accepts.split(',')
        accepts.each do |a|
          a.sub!(/;.+$/i, '');
          a.strip!
        end
        accepts.select! do |a|
          a == '*/*' || a == 'image/*' || SUPPORTED_FORMATS.include?(a)
        end

        if accepts.empty?
          ActiveSupport::Notifications.instrument("unsupported_media_type.bob_ross", {
            accept: env['HTTP_ACCEPT']
          })
          payload[:status] = 415
          return unsupported_media_type
        end
      end

      ActiveSupport::Notifications.instrument("rendered.bob_ross") do |render_payload|
        render_payload[:transformations] = transformation_string
        
        cache_hits = @palette&.get(hash, transformation_string)
        if cache_hits && !cache_hits.empty?
          hit = if options[:format]
            cache_hits.find { |h| h[4] == options[:format] }
          else
            choice = nil
            image_transparent = cache_hits.first[1]

            acs = accepts.dup
            if acs
              while choice.nil? && !acs.empty?
                accept = acs.shift
                if accept == "*/*" || accept == "image/*"
                  choice = (image_transparent == 1 || options[:transparent]) ? 'image/png' : 'image/jpeg'
                elsif SUPPORTED_FORMATS.include?(accept)
                  choice = accept
                end
              end
            else
              choice = (image_transparent == 1 || options[:transparent]) ? 'image/png' : 'image/jpeg'
            end
          
            if choice.nil?
              payload[:status] = 415
              return unsupported_media_type
            end
          
            cache_hits.find { |h| h[4] == choice }
          end

          if hit
            render_payload[:cache] = true
            response_headers['Content-Type']  = hit[4]
            response_headers['Cache-Control'] = @settings[:cache_control] if @settings[:cache_control]
            response_headers['From-Palette']  = '1';
            cached_file = @palette.use(hash, transformation_string, hit[4])
            return [ 200, response_headers, StreamFile.new(cached_file) ]
          end
        end
    
        original_file = if @settings[:store].local?
          File.open(@settings[:store].destination(hash))
        else
          @settings[:store].copy_to_tempfile(hash)
        end
        
        mime_type = @settings[:store].mime_type(hash)
        if mime_type.nil? || mime_type == 'application/octet-stream'
          command = Terrapin::CommandLine.new("file", '-b --mime-type :file')
          mime_type = command.run({ file: original_file.path }).strip
        end

        image = if plugin = BobRoss.plugins[mime_type]
          BobRoss::Image.new(plugin.transform(original_file, transformation_string, transformations), @settings)
        elsif mime_type.start_with?('image/')
          BobRoss::Image.new(original_file, @settings)
        end
        
        return not_implemented if image.nil?
        
        if !options[:format]
          choice = nil
          if accepts
            while choice.nil? && !accepts.empty?
              accept = accepts.shift
              if accept == "*/*" || accept == "image/*"
                choice = (image.transparent || options[:transparent]) ? 'image/png' : 'image/jpeg'
              elsif SUPPORTED_FORMATS.include?(accept)
                choice = accept
              end
            end
          else
            choice = (image.transparent || options[:transparent]) ? 'image/png' : 'image/jpeg'
          end

          if choice.nil?
            payload[:status] = 415
            return unsupported_media_type
          end
      
          options[:format] = choice
        end
    
        transformed_file = image.transform(transformations, options)
    
        # Do this at the end to not cache errors
        payload[:status] = 200
        response_headers['Content-Type'] = options[:format]
        response_headers['Cache-Control'] = @settings[:cache_control] if @settings[:cache_control]
        if @palette
          response_headers['From-Palette'] = '0'
          @palette.set(hash, image.transparent, transformation_string, options[:format], transformed_file.path)
        end
    
        [200, response_headers, StreamFile.new(transformed_file)]
      end
    end
  rescue Errno::ENOENT
    return not_found
  rescue StandardError => e
    if ['Net::OpenTimeout', 'Net::ReadTimeout'].include?(e.class.name)
      return gateway_timeout
    else
      raise
    end
  ensure
    if defined?(original_file)
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
  
  def gateway_timeout
    [504, {"Content-Type" => "text/plain"}, ["504 Gateway Timeout"]]
  end
  
  def gone
    [410, {"Content-Type" => "text/plain"}, ["410 Resource Gone Or No Longer Available"]]
  end
  
  def unsupported_media_type
    [415, {"Content-Type" => "text/plain"}, ["Accept is requesting an Unsupported Media Type"]]
  end
  
  def not_implemented
    [501, {"Content-Type" => "text/plain"}, ["Underlying Media Type is not supported"]]
  end
  
  def extract_options(string)
    options = {}
    transformations = []
    return [options, transformations] unless string
    
    string.scan(/([A-Z])([^A-Z]*)/) do |key, value|
      case key
      when 'B'.freeze
        transformations << { background: "##{value}" }
      when 'C'.freeze
        transformations << { crop: value }
      when 'E'.freeze
        options[:expires] = Time.at(value.to_i(16))
      when 'G'.freeze
        transformations << { grayscale: true }
      when 'I'.freeze
        options[:interlace] = true
      when 'L'.freeze
        options[:lossless] = true
      when 'O'.freeze
        options[:optimize] = true
      when 'P'.freeze
        transformations << { padding: value }
      when 'S'.freeze
        transformations << { resize: value }
      when 'T'.freeze
        options[:transparent] = true
      when 'W'.freeze
        transformations << { watermark: value }
      end
    end
    
    [options, transformations]
  end
  
  def valid_hmac?(hmac, data)
    valid_hmacs = []
    matching_hmac = @settings[:hmac][:attributes].find do |mtds|
      valid_hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), @settings[:hmac][:key], mtds.map{ |k| data[k] }.join(''))
      valid_hmacs.push(valid_hmac)
      valid_hmac == hmac
    end

    if !matching_hmac
      matching_hmac = @settings[:hmac][:attributes].find do |mtds|
        @settings[:hmac][:transformations][:optional].find do |permutation|
          data_copy = data.dup
          permutation.each do |transform|
            data_copy[:transformations] = data_copy[:transformations].gsub(/(#{transform}[^A-Z]*)/, '')
          end
          valid_hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), @settings[:hmac][:key], mtds.map{ |k| data_copy[k] }.join(''))
          valid_hmacs.push(valid_hmac)
          valid_hmac == hmac
        end
      end
    end
    
    if !matching_hmac
      ActiveSupport::Notifications.instrument("invalid_hmac.bob_ross", {
        hmac: hmac,
        valid_hmacs: valid_hmacs
      })
    end
    
    matching_hmac
  end
  
  def accept?(env, mime)
    env['HTTP_ACCEPT'] && env['HTTP_ACCEPT'].include?(mime)
  end

end