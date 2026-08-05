# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

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
  
  # Loads +path+ with libvips, staging SVGs in their own empty directory
  # first. librsvg resolves resources referenced by an SVG from the SVG's
  # own directory (absolute paths, "..", and network URIs are refused), so
  # an SVG rendered from a shared tempdir could bake sibling tempfiles —
  # other uploads or exports in flight — into its output. copy_memory forces
  # the pixels into RAM so the staged copy can be deleted immediately.
  def vips_load_safely(path, **options)
    if ::Vips.vips_foreign_find_load(path)&.start_with?("VipsForeignLoadSvg")
      Dir.mktmpdir do |dir|
        staged = File.join(dir, File.basename(path))
        FileUtils.cp(path, staged)
        return ::Vips::Image.new_from_file(staged, access: :sequential, **options).copy_memory
      end
    else
      ::Vips::Image.new_from_file(path, **options)
    end
  end

  def vips_load(path, cache=false)
    if cache
      @load_cache[path] ||= vips_load_safely(path, **select_valid_loader_options(path, {}))
    else
      vips_load_safely(path, **select_valid_loader_options(path, {}))
    end
  end
end