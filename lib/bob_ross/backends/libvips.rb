require 'ruby-vips'

module BobRoss::LibVipsBackend
  extend BobRoss::BackendHelpers

  SHARPEN_MASK = ::Vips::Image.new_from_array [[-1, -1, -1],
                                               [-1, 32, -1],
                                               [-1, -1, -1]], 24

  class <<self

  def identify(path)
    ident = {}

    mime_command = Terrapin::CommandLine.new("file", '--mime -b :file')
    ident[:mime_type] = mime_command.run({ file: path }).split(';')[0]
    
    i = ::Vips::Image.new_from_file(path, select_valid_loader_options(path, {}))#, access: :sequential
    ident[:opaque]    = i.has_alpha? ? i.extract_band(3, n: 1).min == 255.0 : true
    ident[:geometry]  = { width: i.width, height: i.height, x_offset: nil, y_offset: nil, modifier: nil, gravity: nil, color: nil }
    ident[:orientation] = begin
      i.get('orientation')
    rescue Vips::Error
      nil
    end
    ident
  end

  # width - Width given, height automatically selected to preserve aspect ratio.
  # xheight - Height given, width automatically selected to preserve aspect ratio.
  # widthxheight - Maximum values of height and width given, aspect ratio preserved
  # widthxheight^ - Minimum values of width and height given, aspect ratio preserved.
  # widthxheight! - ignore aspect ratio
  # widthxheight> - shrinks if larger
  # widthxheight< - enlarges if smaller
  # widthxheight# - resize and fill with background
  # widthxheight* - resize to fill dimensions and crop, positioned according to the gravity (default center)
  def fill_geometry(vips, geometry)
    if geometry[:width]
      geometry[:height] ||= (geometry[:width] * vips.height.to_f / vips.width.to_f).round
    elsif geometry[:height]
      geometry[:width] ||= (geometry[:height] * vips.width.to_f / vips.height.to_f).round
    end
    
    if geometry[:modifier] == '*'
      output_width  = (geometry[:height] * vips.width.to_f / vips.height.to_f).round
      if output_width < geometry[:width]
        geometry[:height] = (geometry[:width] * vips.height.to_f / vips.width.to_f).round
      end
      output_height = (geometry[:width] * vips.height.to_f / vips.width.to_f).round
      if output_height < geometry[:height]
        geometry[:width] = (geometry[:height] * vips.width.to_f / vips.height.to_f).round
      end
    end
  end
  
  def resize(image, vips, geometry)
    geometry = parse_geometry(geometry)
    orig_geom = geometry.dup
    fill_geometry(vips, geometry)
    modifier = case geometry[:modifier]
    when '!'
      :force
    when '<'
      :up
    when '>'
      :down
    else
      :both
    end
    
    vips = vips.thumbnail_image(geometry[:width], {
      height: geometry[:height],
      size: modifier
    })

    vips = vips.conv(SHARPEN_MASK) if image.area > (vips.width * vips.height)
    
    if geometry[:modifier] == '#'
      fill_width = (geometry[:width] - vips.width).to_f/2.0
      fill_height = (geometry[:height] - vips.height).to_f/2.0
      vips = pad(vips, {
        top: fill_height.floor,
        right: fill_width.ceil,
        bottom: fill_height.ceil,
        left: fill_width.floor,
        color: geometry[:color]
      })
    elsif geometry[:modifier] == '*'
      if orig_geom[:width]
        orig_geom[:height] ||= (orig_geom[:width] * vips.height.to_f / vips.width.to_f).round
      elsif orig_geom[:height]
        orig_geom[:width] ||= (orig_geom[:height] * vips.width.to_f / vips.height.to_f).round
      end
      vips = crop(vips, orig_geom)
    end
    
    vips
  end
  
  def rgba_to_values(string, bands: 3)
    values = string.delete_prefix('#').scan(/\w{2}/).map { |w| w.to_i(16) }
    values.push(255) if values.size < 4
    values.take(bands)
  end
  
  def crop(vips, geometry)
    geometry = parse_geometry(geometry) if geometry.is_a?(String)
    geometry[:height] = geometry[:width] if geometry[:height].nil?
    geometry[:width] = geometry[:height] if geometry[:width].nil?
    
    if geometry[:x_offset] || geometry[:y_offset]
      vips.extract_area(geometry[:x_offset], geometry[:y_offset], geometry[:width], geometry[:height])
    else
      case geometry[:gravity]
      when 'sm'
        vips.smartcrop(geometry[:width], geometry[:height], interesting: :attention)
      when 'n'
        vips.extract_area(((vips.width - geometry[:width])/2.0).floor, 0, geometry[:width], geometry[:height])
      when 'ne'
        vips.extract_area(vips.width - geometry[:width], 0, geometry[:width], geometry[:height])
      when 'e'
        vips.extract_area(vips.width - geometry[:width], ((vips.height - geometry[:height])/2.0).floor, geometry[:width], geometry[:height])
      when 'se'
        vips.extract_area(vips.width - geometry[:width], vips.height - geometry[:height], geometry[:width], geometry[:height])
      when 's'
        vips.extract_area(((vips.width - geometry[:width])/2.0).floor, vips.height - geometry[:height], geometry[:width], geometry[:height])
      when 'sw'
        vips.extract_area(0, vips.height - geometry[:height], geometry[:width], geometry[:height])
      when 'w'
        vips.extract_area(0, ((vips.height - geometry[:height])/2.0).floor, geometry[:width], geometry[:height])
      when 'nw'
        vips.extract_area(0, 0, geometry[:width], geometry[:height])
      else
        vips.smartcrop(geometry[:width], geometry[:height], interesting: :centre)
      end
    end
  end
  
  def pad(vips, padding)
    vips.embed(padding[:left], padding[:top], vips.width + padding[:right] + padding[:left], vips.height + padding[:bottom] + padding[:top], {
      extend: :background,
      background: rgba_to_values(padding[:color] || '#00000000', bands: vips.bands)
    })
  end
  
  def background(image, vips, background_color)
    bg_color = rgba_to_values(background_color, bands: vips.bands)
    background = vips.new_from_image(bg_color)
    vips = background.composite(vips, :over)
  end
  
  def watermark(image, vips, transform)
    if transform =~ /^(\d+)(\w+)(.*)$/i
      watermark_file = image.settings[:watermarks][$1.to_i]
      watermark_geometry = $3
      watermark_postion = $2.downcase#.gsub(/\w/) { |s| GRAVITIES[s] } 
      
      geometry = parse_geometry(watermark_geometry)
      if !geometry[:width] && !geometry[:height]
        if watermark_postion == 'o'
          geometry[:width] = vips.width
          geometry[:height] = vips.height
        elsif vips.width * vips.height <= 60_000
          geometry[:width] = ([vips.width, vips.height].max * 0.10).floor
          geometry[:height] = geometry[:width]
        elsif vips.width * vips.height <= 90_000
          geometry[:width] = ([vips.width, vips.height].max * 0.08).floor
          geometry[:height] = geometry[:width]
        else
          geometry[:width] = ([vips.width, vips.height].max * 0.05).floor
          geometry[:height] = geometry[:width]
        end
      end
      wtrmrk = ::Vips::Image.new_from_file(watermark_file[:path], select_valid_loader_options(watermark_file[:path], {}))
      wtrmrk = wtrmrk.thumbnail_image(geometry[:width], {height: geometry[:height]})
      geometry[:height] = wtrmrk.height
      geometry[:width] = wtrmrk.width
      
      if watermark_postion == 'o' || (vips.width > geometry[:width] * 2 && vips.height > geometry[:height] * 2)
        default_spacing = (geometry[:width] / 2.0).ceil
        
        case watermark_postion
        when 'n'
          geometry[:x] = ((vips.width - geometry[:width])/2.0).floor
          geometry[:y] = 0
          if !geometry[:x_offset] && !geometry[:y_offset]
            geometry[:x_offset] = 0
            geometry[:y_offset] = default_spacing
          end
        when 'ne'
          geometry[:x] = vips.width - geometry[:width]
          geometry[:y] = 0
          if !geometry[:x_offset] && !geometry[:y_offset]
            geometry[:x_offset] = -default_spacing
            geometry[:y_offset] = default_spacing
          end
        when 'e'
          geometry[:x] = vips.width - geometry[:width]
          geometry[:y] = ((vips.height - geometry[:height])/2.0).floor
          if !geometry[:x_offset] && !geometry[:y_offset]
            geometry[:x_offset] = -default_spacing
            geometry[:y_offset] = 0
          end
        when 'se'
          geometry[:x] = vips.width - geometry[:width]
          geometry[:y] = vips.height - geometry[:height]
          if !geometry[:x_offset] && !geometry[:y_offset]
            geometry[:x_offset] = -default_spacing
            geometry[:y_offset] = -default_spacing
          end
        when 's'
          geometry[:x] = ((vips.width - geometry[:width])/2.0).floor
          geometry[:y] = vips.height - geometry[:height]
          if !geometry[:x_offset] && !geometry[:y_offset]
            geometry[:x_offset] = 0
            geometry[:y_offset] = -default_spacing
          end
        when 'sw'
          geometry[:x] = 0
          geometry[:y] = vips.height - geometry[:height]
          if !geometry[:x_offset] && !geometry[:y_offset]
            geometry[:x_offset] = default_spacing
            geometry[:y_offset] = -default_spacing
          end
        when 'w'
          geometry[:x] = 0
          geometry[:y] = ((vips.height - geometry[:height])/2.0).floor
          if !geometry[:x_offset] && !geometry[:y_offset]
            geometry[:x_offset] = default_spacing
            geometry[:y_offset] = 0
          end
        when 'nw'
          geometry[:x] = 0
          geometry[:y] = 0
          if !geometry[:x_offset] && !geometry[:y_offset]
            geometry[:x_offset] = default_spacing
            geometry[:y_offset] = default_spacing
          end
        when 'c', 'o'
          geometry[:x] = ((vips.width - geometry[:width])/2.0).floor
          geometry[:y] = ((vips.height - geometry[:height])/2.0).floor
          if !geometry[:x_offset] && !geometry[:y_offset]
            geometry[:x_offset] = 0
            geometry[:y_offset] = 0
          end
        end

        padding = { color: '#FFFFFF00' }
        padding[:top] = geometry[:y] + geometry[:y_offset]
        padding[:bottom] = vips.height - geometry[:height] - padding[:top]
        padding[:left] = geometry[:x] + geometry[:x_offset]
        padding[:right] = vips.width - geometry[:width] - padding[:left]

        wtrmrk = pad(wtrmrk, padding)
        vips = vips.composite(wtrmrk, :over)
      end
    end
    vips
  end

  def transform(image, transformations, options)
    vips = ::Vips::Image.new_from_file(image.source.path, select_valid_loader_options(image.source.path, {}))
    vips.add_alpha if !vips.has_alpha?
    
    if image.orientation
      vips = case image.orientation
      when 2
        vips.fliphor
      when 4
        vips.fliphor.rot180
      when 5
        vips.rot90.fliphor
      when 7
        vips.rot270.fliphor
      else
        vips.autorot
      end
    end

    transformations.each do |transform|
      transform.each do |key, value|
        vips = case key
        when :background
          background(image, vips, value)
        when :resize
          resize(image, vips, value)
        when :crop
          crop(vips, value)
        when :grayscale
          vips.colourspace(:'b-w')
        when :padding
          pad(vips, value)
        when :watermark
          watermark(image, vips, value)
        else
          vips
        end
      end
    end
    
    output = Tempfile.new(['blob', ".#{MiniMime.lookup_by_content_type(options[:format]).extension}"], binmode: true)

    # options.each do |key, value|
    #   case key
    #   when :lossless
    #     params << "-define webp:lossless=true"
    #   when :optimize
    #     params << "-quality 85" unless transformations[:format] == 'image/webp'
    #     params << "-define png:compression-filter=5"
    #     params << "-define png:compression-level=9"
    #     params << "-define png:compression-strategy=1"
    #     params << "-define png:exclude-chunk=all"
    #     params << "-interlace none" unless transformations[:interlace]
    #     params << "-colorspace sRGB"
    #     params << "-strip"
    #   when :interlace
    #     params << "-interlace Plane"
    #   end
    # end
    # transformations.delete(:lossless)
    
    vips.write_to_file(output.path, select_valid_saver_options(output.path, {}))
    output
  end
  
  # libvips uses various loaders depending on the input format.
  def select_valid_loader_options(source_path, options)
    loader = ::Vips.vips_foreign_find_load(source_path)
    loader ? select_valid_options(loader, options) : options
  end

  # Filters out unknown options for saving images.
  def select_valid_saver_options(destination_path, options)
    saver = ::Vips.vips_foreign_find_save(destination_path)
    saver ? select_valid_options(saver, options) : options
  end

  # libvips uses various loaders and savers depending on the input and
  # output image format. Each of these loaders and savers accept slightly
  # different options, so to allow the user to be able to specify options
  # for a specific loader/saver and have it ignored for other
  # loaders/savers, we do a little bit of introspection and filter out
  # options that don't exist for a particular loader or saver.
  def select_valid_options(operation_name, options)
    operation = ::Vips::Operation.new(operation_name)

    operation_options = operation.get_construct_args
      .select { |name, flags| (flags & ::Vips::ARGUMENT_INPUT)    != 0 }
      .select { |name, flags| (flags & ::Vips::ARGUMENT_REQUIRED) == 0 }
      .map(&:first).map(&:to_sym)

    options.select { |name, value| operation_options.include?(name) }
  end
  end
end