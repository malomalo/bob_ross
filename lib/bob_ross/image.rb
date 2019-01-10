class BobRoss::Image

  GRAVITIES = {
    'n' => 'North',
    'e' => 'East',
    's' => 'South',
    'w' => 'West',
    'c' => 'Center'
  }
  
  attr_accessor :mime_type, :opaque, :geometry, :orientation
  
  def initialize(file, settings = {})
    @source = file
    @settings = settings
    identify
  end
  
  def default_args
    params = []
    params << "-limit memory :memory_limit" if @settings[:memory_limit]
    params << "-limit map :disk_limit" if @settings[:disk_limit]
    params << "-define registry:temporary-path=:tmpdir"
  end
  
  def identify
    params = default_args
    params << "-format 'Opaque: %[opaque]\nGeometry: %[w]x%[h]\nOrientation: %[EXIF:Orientation]'"
    params << ":file"
    command = Terrapin::CommandLine.new("identify", params.join(' '))

    output = Dir.mktmpdir do |tmpdir|
      command.run({
        file: @source.path,
        tmpdir: tmpdir,
        memory_limit: @settings[:memory_limit],
        disk_limit: @settings[:disk_limit]
      })
    end
    
    mime_command = Terrapin::CommandLine.new("file", '--mime -b :file')
    
    @mime_type = MiniMime.lookup_by_content_type(mime_command.run({ file: @source.path }).split(';')[0]).content_type
    @opaque = output.match(/^Opaque:\s(true|false)\s*$/i)[1] == 'True'
    @geometry = parse_geometry(output.match(/^Geometry:\s([0-9x\-\+]+)\s*$/i)[1])
    @orientation = output.match(/^Orientation:\s(\d)\s*$/i)
    @orientation = @orientation[1].to_i if @orientation
  end
  
  def transform(transformations)
    return @source if (transformations.keys - [:format]).empty? && @mime_type == transformations[:format].content_type && [nil, 1].include?(@orientation)
    
    if transformations[:padding]
      padding = transformations[:padding].split(',').map(&:to_i)
      padding[1] ||= padding[0]
      padding[2] ||= padding[0]
      padding[3] ||= padding[1]
      transformations[:padding] = {
        top: padding[0],
        right: padding[1],
        bottom: padding[2],
        left: padding[3]
      }
      
      if transformations[:resize]
        g = parse_geometry(transformations[:resize])
        g[:width] -= (transformations[:padding][:left] + transformations[:padding][:right])
        g[:height] -= (transformations[:padding][:top] + transformations[:padding][:bottom])
        transformations[:resize] = "#{g[:width]}x#{g[:height]}#{transformations[:resize].sub(/^(\d+)?(?:x(\d+))?([+-]\d+)?([+-]\d+)?/, '')}"
      else
        @geometry[:width] += transformations[:padding][:left] + transformations[:padding][:right]
        @geometry[:height] += transformations[:padding][:top] + transformations[:padding][:bottom]
      end
    end
    
    params = default_args
    
    transformations[:background] ||= '#00000000'
    params << "-background :background"

    params << "\\(" << ":input -colorspace sRGB -auto-orient"
    if transformations[:resize]
      params << "-resize :resize"
      if idx = transformations[:resize].index('*')
        params << "-gravity :resize_gravity -crop :resize_crop"
        if transformations[:resize] =~ /[\*\^](\w+)$/i
          transformations[:resize_gravity] = $1.gsub(/\w/) { |s| GRAVITIES[s] }
        else
          transformations[:resize_gravity] = 'Center'
        end

        transformations[:resize_crop] = transformations[:resize][0...idx] + "+0+0"
        transformations[:resize] = transformations[:resize][0...idx] + "^"
      end
    end

    params << "-alpha remove" if transformations[:background]
    params << "\\)"

    output_size = if transformations[:resize]
      parse_geometry(transformations[:resize])
    else
      @geometry
    end

    if transformations[:watermark] =~ /^(\d+)(\w{2})(.*)$/i
      transformations[:watermark_file] = @settings[:watermarks][$1.to_i]
      transformations[:watermark_geometry] = $3
      
      transformations[:watermark_postion] = $2.gsub(/\w/) { |s| GRAVITIES[s] } 
      
      geo = parse_geometry(transformations[:watermark_geometry])
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
    
    if idx = transformations[:resize]&.index('#')
      params << "-gravity :resize_gravity"
      if transformations[:resize] =~ /[\#\^](\w+)$/i
        transformations[:resize_gravity] = $1.gsub(/\w/) { |s| GRAVITIES[s] }
        
      else
        transformations[:resize_gravity] = 'Center'
      end
      
      params << "-extent :extent"
      transformations[:extent] = transformations[:resize][0...idx]
      transformations[:resize] = transformations[:resize][0...idx]
    end
    
    if transformations[:padding]
      params << "-gravity Center -extent :extent -gravity center -extent :padding"
      
      transformations[:extent] = "#{output_size[:width]}x#{output_size[:height]}"
      w = output_size[:width] + transformations[:padding][:left] + transformations[:padding][:right]
      h = output_size[:height] + transformations[:padding][:top] + transformations[:padding][:bottom]
      x = transformations[:padding][:right] - transformations[:padding][:left]
      y = transformations[:padding][:bottom] - transformations[:padding][:top]
      
      transformations[:padding] = "#{w}x#{h}#{sprintf("%+d", x)}#{sprintf("%+d", y)}"
    end

    if transformations[:crop]
      params << '+repage -crop :crop'
      if transformations[:crop] =~ /[+-]\d+[+-]\d+\Z/
      elsif transformations[:crop] =~ /[+-]\d+\Z/
        transformations[:crop] += "+0"
      else
        transformations[:crop] += "+0+0"
      end
    end
      
    transformations.each do |key, value|
      case key
      when :lossless
        params << "-define webp:lossless=true"
      when :optimize
        params << "-quality 85" unless transformations[:format].content_type == 'image/webp'
        params << "-define png:compression-filter=5"
        params << "-define png:compression-level=9"
        params << "-define png:compression-strategy=1"
        params << "-define png:exclude-chunk=all"
        params << "-interlace none" unless transformations[:interlace]
        params << "-colorspace sRGB"
        params << "-strip"
      when :interlace
        params << "-interlace Plane"
      when :grayscale
        params << "-colorspace gray"
      end
    end
    transformations.delete(:lossless)
    
    params << ":output"
    output = Tempfile.new(['blob', ".#{transformations[:format].extension}"], binmode: true)
    
    begin
      command = Terrapin::CommandLine.new("convert", params.join(' '))
      Dir.mktmpdir do |tmpdir|
        command.run(transformations.merge({
          input: @source.path,
          output: output.path,
          tmpdir: tmpdir,
          memory_limit: @settings[:memory_limit],
          disk_limit: @settings[:disk_limit]
        }))
      end
    rescue => e
      output.close!
      raise
    end
    
    output
  end
  
  def transparent
    @opaque == false
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
  
end