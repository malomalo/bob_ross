# frozen_string_literal: true

module BobRoss::BackendHelpers

  GRAVITIES = {
    'n' => 'North',
    'e' => 'East',
    's' => 'South',
    'w' => 'West',
    'c' => 'Center',
    'sm' => 'Smart'
  }
  
  def self.extended(base)
    base.instance_variable_set(:@load_cache, {})
  end

  def parse_geometry(string, require_dimension: true)
    string =~ /^(\d+)?(?:x(\d+))?([+-]\d+)?([+-]\d+)?([^a-z]*)([neswcm]+)?(?:p(.*))?$/
    
    raise BobRoss::InvalidTransformationError.new("Invalid geometry \"#{string}\"") if require_dimension && $1.nil? && $2.nil?
    
    {
      width: $1 ? $1.to_i : nil,
      height: $2 ? $2.to_i : nil,
      x_offset: $3 ? $3.to_i : nil,
      y_offset: $4 ? $4.to_i : nil,
      modifier: ($5 && !$5.empty?) ? $5 : nil,
      gravity: ($6 && !$6.empty?) ? $6 : nil,
      color: $7
    }
  end
  
  # Loads +path+ with libvips. SVGs are read into memory and loaded from the
  # buffer: an SVG loaded from data has no base URI, so librsvg cannot
  # resolve ANY referenced resource — relative or absolute — while
  # self-contained data: URIs keep working. An SVG rendered from its file
  # path could instead read sibling files (e.g. other uploads in a shared
  # tempdir) into its output.
  def vips_load_safely(path, **options)
    if ::Vips.vips_foreign_find_load(path)&.start_with?("VipsForeignLoadSvg")
      ::Vips::Image.new_from_buffer(File.binread(path), "",
        **select_valid_options("VipsForeignLoadSvgBuffer", options))
    else
      ::Vips::Image.new_from_file(path, **select_valid_loader_options(path, options))
    end
  end

  def vips_load(path, cache=false)
    if cache
      @load_cache[path] ||= vips_load_safely(path)
    else
      vips_load_safely(path)
    end
  end
end