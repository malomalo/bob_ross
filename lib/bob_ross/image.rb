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
  
  def transform(transformations, options={})
    transformations = [transformations].compact if !transformations.is_a?(Array)
    return @source if transformations.empty? && @mime_type == options[:format] && [nil, 1].include?(@orientation)
    options[:format] ||= mime_type
    
    transformations.unshift({transparent: true}) if options[:transparent]
    
    transformations.each do |t|
      if t[:padding]
        padding = t[:padding].split(',')
        padding_color = if padding.last.index('w')
          lp, c = padding.pop.split('w')
          padding << lp if !lp.empty?
          c.delete_prefix('w')
        end
        padding.map!(&:to_i)
        padding[1] ||= padding[0]
        padding[2] ||= padding[0]
        padding[3] ||= padding[1]
        t[:padding] = {
          top: padding[0],
          right: padding[1],
          bottom: padding[2],
          left: padding[3],
          color: "##{padding_color || 'FFFFFF00'}"
        }
      end
    end
    
    BobRoss.backend.transform(self, transformations, options)
  end
  
  def transparent?
    @opaque == false
  end

  def aspect_ratio
    geometry[:width].to_f / geometry[:height].to_f
  end
  
  def area
    geometry[:width] * geometry[:height]
  end
  
end