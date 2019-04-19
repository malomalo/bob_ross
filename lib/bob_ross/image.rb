class BobRoss::Image
  include BobRoss::BackendHelpers
  
  attr_reader :source, :settings
  attr_accessor :mime_type, :opaque, :geometry, :orientation
  
  def initialize(file, settings = {})
    file = File.open(file) if file.is_a?(String)
    @source = file
    @settings = settings
    identify
  end
  
  def identify
    ident = BobRoss.backend.identify(self.source.path)
    self.mime_type = ident[:mime_type]
    self.opaque = ident[:opaque]
    self.orientation = ident[:orientation]
    self.geometry = ident[:geometry]
  end
  
  def transform(transformations)
    return @source if (transformations.keys - [:format]).empty? && @mime_type == transformations[:format] && [nil, 1].include?(@orientation)
    transformations[:format] ||= mime_type
    
    if transformations[:padding]
      padding = transformations[:padding].split(',')
      padding_color = if padding.last.index('w')
        lp, c = padding.pop.split('w')
        padding << lp if !lp.empty?
        c.delete_prefix('w')
      end
      padding.map!(&:to_i)
      padding[1] ||= padding[0]
      padding[2] ||= padding[0]
      padding[3] ||= padding[1]
      transformations[:padding] = {
        top: padding[0],
        right: padding[1],
        bottom: padding[2],
        left: padding[3],
        color: "##{padding_color || 'FFFFFF00'}"
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
    
    BobRoss.backend.transform(self, transformations)
  end
  
  def transparent
    @opaque == false
  end

  def aspect_ratio
    geometry[:width].to_f / geometry[:height].to_f
  end
  
  def area
    geometry[:width] * geometry[:height]
  end
  
end