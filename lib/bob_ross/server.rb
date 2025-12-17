# frozen_string_literal: true

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
  
  SUPPORTED_FORMATS = {
    'image/avif' => {transparency: true,  lossless: true},
    'image/heic' => {transparency: true,  lossless: true},
    'image/webp' => {transparency: true,  lossless: true},
    'image/jp2' =>  {transparency: true,  lossless: true},
    'image/jpeg' => {transparency: false, lossless: false},
    'image/png' =>  {transparency: true,  lossless: true}
  }

  class StreamFile
    def initialize(file)
      @file = File.open(file.path)
    end
    
    def each
      @file.seek(0)
      while part = @file.read(16_384)
        yield part
      end
    end
  end
  
  attr_accessor :settings, :cache, :logger
  
  def initialize(settings={})
    @settings = normalize_options(settings)
    @cache = @settings[:cache]
    @settings[:last_modified_header] = false unless @settings.has_key?(:last_modified_header)
    @logger = (@settings.has_key?(:logger) ? @settings.delete(:logger) : Logger.new(STDOUT))
    
    @useable_formats = SUPPORTED_FORMATS.select { |k,v| BobRoss.backend.supports?(k) }
  end
  
  def serve_file(status, headers, file)
    headers['Content-Length'] = file.size
    [status, headers, StreamFile.new(file)]
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
      
      result[:hmac][:transformations] = { }
      if options[:hmac][:transformations] && options[:hmac][:transformations][:optional]
        ignorable_transformations = if options[:hmac][:transformations][:optional].is_a?(Array)
          options[:hmac][:transformations][:optional]
        else
          [ options[:hmac][:transformations][:optional] ]
        end
        ignorable_transformations.map! { |t| BobRoss.transformations[t.to_sym] }
        
        result[:hmac][:transformations][:optional] = []
        ignorable_transformations.size.times do |i|
          ignorable_transformations.permutation(i+1).each do |pm|
            result[:hmac][:transformations][:optional] << pm
          end
        end
      end

      result[:hmac][:required] = (options[:hmac].has_key?(:required) ? options[:hmac][:required] : true)
    end
    
    if options[:cache] && options[:cache].is_a?(Hash) && !options[:cache].empty?
      require 'bob_ross/cache'
      result[:cache] = BobRoss::Cache.new(
        options[:cache][:path],
        options[:cache][:file],
        size: options[:cache][:size]
      )
    end
    
    if options[:watermarks]
      if BobRoss.backend.key == :vips
        # Because of https://github.com/libvips/ruby-vips/issues/396
        # and https://github.com/libvips/ruby-vips/issues/155 we'll identify
        # in a fork to allow for forking of the server process in production 
        # and/or parrallel testing
        options[:watermarks].map! do |watermark_path|
          {
            path: watermark_path,
            geometry: result_from_fork { BobRoss.backend.identify(watermark_path)[:geometry] }
          }
        end
      else
        options[:watermarks].map! do |watermark_path|
          {
            path: watermark_path,
            geometry: BobRoss.backend.identify(watermark_path)[:geometry]
          }
        end
      end
    end

    result
  end
  
  # TODO: remove once the watermark isssue in normalize_options is resolved
  def result_from_fork
    read, write = IO.pipe
    pid = fork do
      read.close
      result = yield
      Marshal.dump(result, write)
      exit!(0) # skips exit handlers.
    end
    
    write.close
    result = read.read
    Process.wait(pid)
    raise "Issue with identifing watermark" if result.empty?
    Marshal.load(result)
  end
  
  def call(env)
    image =nil
    ActiveSupport::Notifications.instrument("start_processing.bob_ross")
    
    ActiveSupport::Notifications.instrument("process.bob_ross") do |payload|
      path = ::URI::DEFAULT_PARSER.unescape(env['PATH_INFO']).force_encoding('UTF-8')
      match = path.match(/\A\/(?:([A-Z][^\/]*)\/?)?([0-9a-z\-]+)(?:\/[^\/]+?)?(\.\w+)?\Z/)
    
      if !match
        payload[:status] = 404
        return not_found
      end

      response_headers = {}
    
      transformation_string = match[1] || String.new
      hash = match[2]
      requested_format = match[3]
      
      if transformation_string.start_with?('H')
        match = transformation_string.match(/^H([^A-Z]+)(?=[A-Z]|\z)/)
        provided_hmac = match[1]
        transformation_string.delete_prefix!(match[0])
      
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
      
      if transformation_string.start_with?('E')
        match = transformation_string.match(/^E([^A-Z]+)(?=[A-Z]|\z)/)
        expiration_time = Time.at(match[1].to_i(16))
        transformation_string.delete_prefix!(match[0])

        if expiration_time <= Time.now
          ActiveSupport::Notifications.instrument("expired.bob_ross", {
            expired_at: expiration_time
          })
          payload[:status] = 410
          return gone
        end
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

      format_options, format_options_string = extract_format_options(transformation_string)
      
      if requested_format
        format_options[:format] = MiniMime.lookup_by_extension(requested_format.delete_prefix('.')).content_type
      else
        response_headers['Vary'] = 'Accept'
      end

      if accepts = env['HTTP_ACCEPT']
        accepts = accepts.split(',')
        accepts.each do |a|
          a.sub!(/;.+$/i, '')
          a.strip!
        end
        accepts.select! do |a|
          a == '*/*' || a == 'image/*' || @useable_formats.has_key?(a)
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
        transform_key = transformation_string + format_options_string
        
        cache_hits = @cache&.get(hash, transform_key)
        if cache_hits && !cache_hits.empty?
          format_options[:format] ||= select_format(accepts, (cache_hits.first[1] == 1) || format_options[:transparent])

          if hit = cache_hits.find { |h| h[4] == format_options[:format] }
            render_payload[:cache] = true
            response_headers['Content-Type']  = hit[4]
            response_headers['Cache-Control'] = @settings[:cache_control] if @settings[:cache_control]
            response_headers['From-Cache']  = '1';
            if cached_file = @cache.use(hash, transform_key, hit[4])
              return serve_file(200, response_headers, cached_file)
            end
          end
        end

        original_file = if @settings[:store].local?
          original_is_temp = false
          File.open(@settings[:store].destination(hash))
        else
          original_is_temp = true
          @settings[:store].copy_to_tempfile(hash)
        end
        
        mime_type = @settings[:store].mime_type(hash)
        if mime_type.nil? || mime_type == 'application/octet-stream'
          command = Terrapin::CommandLine.new("file", '-b --mime-type :file')
          mime_type = command.run({ file: original_file.path }).strip
        end

        transformations = []
        image = if plugin = BobRoss.plugins.find { |k,v| k.is_a?(Regexp) ? k.match(mime_type) : k == mime_type }&.[](1)
          plugin_transformations = plugin.extract_transformations(transformation_string)
          transformations = extract_transformations(transformation_string)
          plugin_file = plugin.transform(original_file, plugin_transformations, transformations)
          original_file.close
          File.unlink(original_file.path) if original_is_temp
          BobRoss::Image.new(plugin_file, @settings, temp: true)
        elsif mime_type.start_with?('image/')
          transformations = extract_transformations(transformation_string)
          BobRoss::Image.new(original_file, @settings, temp: original_is_temp)
        end
        
        return not_implemented if image.nil?
    
        format_options[:format] ||= select_format(accepts, image.transparent? || format_options[:transparent])
        image.transform(transformations, format_options) do |output|
          # Do this at the end to not cache errors
          payload[:status] = 200
          response_headers['Content-Type'] = format_options[:format]
          response_headers['Cache-Control'] = @settings[:cache_control] if @settings[:cache_control]
          if @cache
            response_headers['From-Cache'] = '0'
            @cache.set(hash, image.transparent?, transform_key, format_options[:format], output.path)
          end

          serve_file(200, response_headers, output)
        end
      end
    end
  rescue Errno::ENOENT
    return not_found
  rescue BobRoss::InvalidTransformationError => e
    return unprocessable_entity(e.message)
  rescue StandardError => e
    if ['Net::OpenTimeout', 'Net::ReadTimeout'].include?(e.class.name)
      return gateway_timeout
    else
      raise
    end
  ensure
    image&.close
  end
  
  private
  
  def select_format(accepts, image_transparent)
    if accepts.nil? || accepts.empty?
      image_transparent ? 'image/png' : 'image/jpeg'
    else
      accepts = accepts.reduce([]) do |memo, accept|
        if accept == "*/*" || accept == "image/*"
          memo << (image_transparent ? 'image/png' : 'image/jpeg')
        elsif supported_format = @useable_formats[accept]
          if image_transparent
            memo << accept if supported_format[:transparency]
          else
            memo << accept
          end
        end
        memo
      end
      @useable_formats.keys.find { |f|  accepts.include?(f) }
    end
  end
  
  def not_modified
    [304, {}, []]
  end
  
  def not_found
    [404, {"Content-Type" => "text/plain"}, ["404 Not Found"]]
  end
  
  def unprocessable_entity(message)
    [422, {"Content-Type" => "text/plain"}, [message || "422 Unprocessable Entity"]]
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
  
  def extract_format_options(string)
    options = {}
    return [options, ''] unless string
    
    options_string = ''
    string.gsub!(/([ILOTD]|Q\d+)+\z/) do |match|
      options_string = match if match
      match&.scan(/([A-Z])([^A-Z]*)/) do |key, value|
        case key
        when 'D'.freeze
          options[:strip] = true
        when 'I'.freeze
          options[:interlace] = true
        when 'L'.freeze
          options[:lossless] = true
        when 'O'.freeze
          options[:optimize] = true
        when 'T'.freeze
          options[:transparent] = true
        when 'Q'.freeze
          options[:quality] = value.to_i
        end
      end
      ''
    end
    
    [options, options_string]
  end
  
  def extract_transformations(string)
    transformations = []
    return transformations unless string
    
    string.scan(/([A-Z])([^A-Z]*)/) do |key, value|
      case key
      when 'B'
        transformations << { background: "##{value}" }
      when 'C'
        transformations << { crop: value }
      when 'G'
        transformations << { grayscale: true }
      when 'P'
        transformations << { padding: value }
      when 'R'.freeze
        if value.start_with?('o')
          value = value.delete_prefix('o')
          transformations << { rotate: value.index('.') ? value.to_f : value.to_i }
        end
      when 'S'
        transformations << { resize: value }
      when 'W'
        transformations << { watermark: value }
      end
    end
    
    transformations
  end
  
  def valid_hmac?(hmac, data)
    valid_hmacs = []
    matching_hmac = @settings[:hmac][:attributes].find do |mtds|
      valid_hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), @settings[:hmac][:key], mtds.map{ |k| data[k] }.join(''))
      valid_hmacs.push(valid_hmac)
      valid_hmac == hmac
    end

    if !matching_hmac && @settings[:hmac][:transformations][:optional]
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