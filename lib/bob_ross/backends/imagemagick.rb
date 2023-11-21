module BobRoss::ImageMagickBackend
  extend BobRoss::BackendHelpers
  
  class <<self
  
  def version
    return @version if @version
    version_cmd = Terrapin::CommandLine.new("identify", '-version')
    @version = version_cmd.run.match(/Version: ImageMagick (\S+)/)[1]
  end
  
  def supports?(*mimes)
    (mimes - supported_formats).empty?
  end
  
  def supported_formats
    return @supported_formats if @supported_formats
    
    formats_cmd = Terrapin::CommandLine.new("identify", '-list format')
    
    @supported_formats = formats_cmd.run.gsub(/\s{10,}[^\n]+(?=\n)/, '').lines[2..-6].reduce([]) do |memo, line|
      line = line.split(/\s+/).select { |c| !c.empty? }
      if line[2][1] == 'w'
        mime = MiniMime.lookup_by_extension(line[0].delete_suffix('*').downcase)
        memo << mime.content_type if mime
      end
      memo
    end
  end
  
  def default_args(options)
    params = []
    params << "-limit memory :memory_limit" if options[:memory_limit]
    params << "-limit map :disk_limit" if options[:disk_limit]
    params << "-define registry:temporary-path=:tmpdir" if options[:tmpdir]
    params
  end
  
  def identify(path)
    ident = {}
    
    mime_command = Terrapin::CommandLine.new("file", '--mime -b :file')
    ident[:mime_type] = mime_command.run({ file: path }).split(';')[0]
    
    params = []#default_args(image.settings)
    params << "-format 'Opaque: %[opaque]\nGeometry: %[w]x%[h]\nOrientation: %[EXIF:Orientation]'"
    params << ":file"
    command = Terrapin::CommandLine.new("identify", params.join(' '))

    output = command.run(file: path)
    ident[:opaque]    = output.match(/^Opaque:\s(true|false)\s*$/i)[1] == 'True'
    ident[:geometry]  = parse_geometry(output.match(/^Geometry:\s([0-9x\-\+]+)\s*$/i)[1])
    orientation = output.match(/^Orientation:\s(\d)\s*$/i)
    ident[:orientation] = orientation[1].to_i if orientation
    ident
  end

  def transform(image, transformations, options)
    params = default_args(image.settings)
    params << "-background none :input -colorspace sRGB -auto-orient"
    
    interpolations = { size: image.geometry }

    transformations.each do |transform|
      transform.each do |key, value|
        params << case key
        when :background
          background(value, interpolations)
        when :resize
          resize(value, interpolations)
        when :crop
          crop(value, interpolations)
        when :grayscale
          "-colorspace gray"
        when :padding
          pad(value, interpolations)
        when :watermark
          watermark(value, interpolations, image)
        when :transparent
          "-alpha Set"
        else
          nil
        end
      end
    end
    
    case options[:format]
    when 'image/avif'
      params << "-quality 45" unless options[:quality]
    when 'image/heic'
      params << "-quality 40" unless options[:quality]
    when 'image/webp'
      params << "-quality 45" unless options[:quality]
    when 'image/jp2'
      params << "-quality 40" unless options[:quality]
    when 'image/jpeg'
      params << "-quality 43" unless options[:quality]
      params << "-define jpeg:optimize-coding=on"
    when 'image/png'
      params << "-define png:compression-level=9"
    end
    
    options.each do |key, value|
     case key
     when :quality
       params << "-quality " << if %w(image/jpeg image/jp2 image/heif image/avif).include?(options[:format])
         [[1, value.to_i].max, 100].min.to_s
       else
         value.to_i
       end
     when :strip
       params << "-strip"
     when :lossless
       params << "-define webp:lossless=true"
     when :interlace
       params << "-interlace Plane"
     end
    end
    
    params << ":output"
    output = Tempfile.new(['blob', ".#{MiniMime.lookup_by_content_type(options[:format]).extension}"], binmode: true)
    begin
      command = Terrapin::CommandLine.new("convert", params.join(' '))
      Dir.mktmpdir do |tmpdir|
        command.run(interpolations.merge({
          input:        image.source.path,
          output:       output.path,
          tmpdir:       tmpdir,
          memory_limit: image.settings[:memory_limit],
          disk_limit:   image.settings[:disk_limit]
        }))
      end
    rescue => e
      output.close!
      raise
    end
    
    output
  end
  
  def background(transform, interpolations)
    interpolations[:background] = transform
    "-background :background -flatten"
  end
  
  def resize(transform, interpolations)
    params = []
    params << "\\("
    params << "-resize :resize -unsharp 0x0.75+0.75+0.008"
    interpolations[:resize] = transform
    
    if idx = transform.index('*')
      params << "-gravity :resize_gravity -crop :resize_crop"
      if transform =~ /[\*\^](\w+)$/i
        interpolations[:resize_gravity] = $1.gsub(/\w/) { |s| GRAVITIES[s] }
      else
        interpolations[:resize_gravity] = 'Center'
      end

      interpolations[:resize_crop] = transform[0...idx] + "+0+0"
      interpolations[:resize] = transform[0...idx] + "^"
    end
    params << "\\)"
    
    if idx = transform.index('#')
      if transform =~ /p(\w+)$/i
        params << "-background :resize_background -compose Copy"
        interpolations[:resize_background] = "##{$1}"
      end

      params << "-gravity :resize_gravity"
      if transform =~ /[\#\^]([neswco]+)$/i
        interpolations[:resize_gravity] = $1.gsub(/\w/) { |s| GRAVITIES[s] }
      else
        interpolations[:resize_gravity] = 'Center'
      end
      
      params << "-extent :resize_extent"
      interpolations[:resize_extent]  = transform[0...idx]
      interpolations[:resize]         = transform[0...idx]
      interpolations[:size]           = parse_geometry(transform)
    else
      old_size = interpolations[:size].dup
      new_size = parse_geometry(transform)

      if new_size[:modifier] == '>' && old_size[:width] < new_size[:width] && old_size[:height] < new_size[:height]
      elsif new_size[:modifier] == '<' && old_size[:width] > new_size[:width] && old_size[:height] > new_size[:height]
      else
        interpolations[:size][:height] = new_size[:height] || new_size[:width]
        interpolations[:size][:width]  = (interpolations[:size][:height] * (old_size[:width].to_f / old_size[:height].to_f)).round
      
        if interpolations[:size][:width] > (new_size[:height] || new_size[:width])
          interpolations[:size][:width]   = new_size[:width] || new_size[:height]
          interpolations[:size][:height]  = (interpolations[:size][:width] *  old_size[:height].to_f / old_size[:width].to_f).round
        end
      end
    end

    params << "+repage"
    params
  end

  def watermark(transform, interpolations, image)
    transform =~ /^(\d+)(\w{1,2})(.*)$/i
    params = []

    mark = image.settings[:watermarks][$1.to_i]
    interpolations[:watermark_file] = mark[:path]
    interpolations[:watermark_geometry] = $3
    watermark_postion = $2
      
    geo = parse_geometry(interpolations[:watermark_geometry])
    if !geo[:width] && !geo[:height]
      if watermark_postion == 'o'
        wtrmrk_image = image.settings[:watermarks][$1.to_i][:geometry]
        geo[:height]  = interpolations[:size][:height]
        geo[:width]   = (interpolations[:size][:height] * (mark[:geometry][:width].to_f / mark[:geometry][:height].to_f)).round
        
        if geo[:width] > interpolations[:size][:width]
          geo[:width]  = interpolations[:size][:width]
          geo[:height]  = (interpolations[:size][:width] *  mark[:geometry][:height].to_f / mark[:geometry][:width].to_f).round
        end
      elsif interpolations[:size][:width] * interpolations[:size][:height] <= 60_000
        geo[:width] = ([interpolations[:size][:width], interpolations[:size][:height]].max * 0.10).floor
        geo[:height] = geo[:width]
      elsif interpolations[:size][:width] * interpolations[:size][:height] <= 90_000
        geo[:width] = ([interpolations[:size][:width], interpolations[:size][:height]].max * 0.08).floor
        geo[:height] = geo[:width]
      else
        geo[:width] = ([interpolations[:size][:width], interpolations[:size][:height]].max * 0.05).floor
        geo[:height] = geo[:width]
      end
    end
    
    default_spacing = (geo[:width] / 2.0).ceil
    case watermark_postion
    when 'n', 's'
      geo[:x_offset] ||= 0
      geo[:y_offset] ||= default_spacing
    when 'ne', 'se', 'sw', 'nw'
      geo[:x_offset] ||= default_spacing
      geo[:y_offset] ||= default_spacing
    when 'e', 'w'
      geo[:x_offset] ||= default_spacing
      geo[:y_offset] ||= 0
    when 'w'
      geo[:x_offset] ||= -default_spacing
      geo[:y_offset] ||= 0
    end
    
    interpolations[:watermark_geometry] = "#{geo[:width]}x#{geo[:height]}"
    interpolations[:watermark_geometry] << if geo[:x_offset]
      geo[:x_offset] < 0 ? geo[:x_offset].to_s : "+#{geo[:x_offset]}"
    else
      '+0'
    end
    interpolations[:watermark_geometry] << if geo[:y_offset]
      geo[:y_offset] < 0 ? geo[:y_offset].to_s : "+#{geo[:y_offset]}"
    else
      '+0'
    end
    
    if watermark_postion == 'o' || interpolations[:size][:width] > geo[:width] * 2 && interpolations[:size][:height] > geo[:height] * 2
      interpolations[:watermark_postion] = watermark_postion.gsub('o', 'c').gsub(/\w/) { |s| GRAVITIES[s] }
      params << "\\( -background none :watermark_file -gravity :watermark_postion -geometry :watermark_geometry \\) -compose over -composite"
    end

    params
  end
  
  def pad(transform, interpolations)
    params = []
    
    params << "-gravity northeast -background :padding_background -splice :padding_splice_a"
    interpolations[:padding_splice_a] = "#{transform[:right]}x#{transform[:top]}"
    params << "-gravity southwest -background :padding_background -splice :padding_splice_b"
    interpolations[:padding_splice_b] = "#{transform[:left]}x#{transform[:bottom]}"
    interpolations[:padding_background] = transform[:color]
    
    interpolations[:size][:width]   += transform[:right] + transform[:left]
    interpolations[:size][:height]  += transform[:top] + transform[:bottom]
    params
  end

  def crop(transform, interpolations)
    params = []
    
    crop_geom = parse_geometry(transform)
    crop_geom[:height] = crop_geom[:width] if crop_geom[:height].nil?
    crop_geom[:width] = crop_geom[:height] if crop_geom[:width].nil?
    crop_geom[:gravity] ||= 'c'

    if crop_geom[:x_offset] || crop_geom[:y_offset]
      params << "-crop :crop_size"
    else
      params << "-gravity :crop_gravity -crop :crop_size"
    end

    interpolations[:crop_gravity] = crop_geom[:gravity].gsub(/\w/) { |s| GRAVITIES[s] }

    interpolations[:crop_size] = "#{crop_geom[:width]}x#{crop_geom[:height]}"
    interpolations[:crop_size] << if crop_geom[:x_offset]
      crop_geom[:x_offset] < 0 ? crop_geom[:x_offset].to_s : "+#{crop_geom[:x_offset]}"
    else
      '+0'
    end
    interpolations[:crop_size] << if crop_geom[:y_offset]
      crop_geom[:y_offset] < 0 ? crop_geom[:y_offset].to_s : "+#{crop_geom[:y_offset]}"
    else
      '+0'
    end
    
    params
  end
  end
end