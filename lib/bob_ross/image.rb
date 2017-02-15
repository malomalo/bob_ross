class BobRoss::Image

  attr_accessor :mime_type, :opaque, :geometry
  
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
    params << "-format 'Opaque: %[opaque]\nGeometry: %[w]x%[h]\n'"
    params << ":file"
    command = Cocaine::CommandLine.new("identify", params.join(' '))

    output = Dir.mktmpdir do |tmpdir|
      command.run({
        file: @source.path,
        tmpdir: tmpdir,
        memory_limit: @settings[:memory_limit],
        disk_limit: @settings[:disk_limit]
      })
    end
    
    mime_command = Cocaine::CommandLine.new("file", '--mime -b :file')
    
    @mime_type = MIME::Types[mime_command.run({ file: @source.path }).split(';')[0]].first
    @opaque = output.match(/^Opaque:\s(true|false)\s*$/i)[1] == 'True'
    @geometry = parse_geometry(output.match(/^Geometry:\s([0-9x\-\+]+)\s*$/i)[1])
  end
  
  def transform(transformations)
    return @source if (transformations.keys - [:dpr, :format]).empty? && @mime_type == transformations[:format]
    
    params = default_args
    
    transformations[:background] ||= '#00000000'
    params << "-background :background"

    params << "\\(" << ":input -auto-orient"
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
      transformations[:watermark_file] = @settings[:watermarks][$1.to_i]
      transformations[:watermark_geometry] = $3
      transformations[:watermark_postion] = $2.sub('n', 'North').sub('e', 'East').sub('s', 'South').sub('w', 'West')
      
      geo = parse_geometry(transformations[:watermark_geometry])
      output_size = if transformations[:resize]
        parse_geometry(transformations[:resize])
      else
        @geometry
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
        params << "-quality 85" unless transformations[:format].to_s == 'image/webp'
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
    output = Tempfile.new(['blob', ".#{transformations[:format].preferred_extension}"], :binmode => true)
    
    begin
      command = Cocaine::CommandLine.new("convert", params.join(' '))
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