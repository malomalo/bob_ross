# frozen_string_literal: true

class BobRoss::Image
  include BobRoss::BackendHelpers
  
  attr_reader :source, :settings
  attr_accessor :mime_type, :opaque, :geometry, :orientation
  
  def initialize(file, settings = {}, temp: false)
    file = File.open(file) if file.is_a?(String)
    @source = file
    @settings = settings
    @source_is_tempfile = temp
    identify
  end
  
  def identify
    ident = BobRoss.backend.identify(self.source.path)
    self.mime_type = ident[:mime_type]
    self.opaque = ident[:opaque]
    self.orientation = ident[:orientation]
    self.geometry = ident[:geometry]
  end
  
  # All files returned from transform are assume to be Tempfiles and will be
  # removed
  def transform(transformations, options={})
    transformations = [transformations].compact if !transformations.is_a?(Array)
    if transformations.empty? && @mime_type == options[:format] && [nil, 1].include?(@orientation)
      return yield(@source)
    end
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
    
    begin
      transformed_file = BobRoss.backend.transform(self, transformations, options)
      yield(transformed_file)
    ensure
      if transformed_file
        transformed_file.close
        File.unlink(transformed_file.path)
      end
    end
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
  
  # close the underlying file; and if a temp file unlink it
  def close
    @source.close
    File.unlink(@source.path) if @source_is_tempfile
  end

end