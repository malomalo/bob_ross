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
  
  def vips_load(path, cache=false)
    if cache
      @load_cache[path] ||= ::Vips::Image.new_from_file(path, **select_valid_loader_options(path, {}))
    else
      ::Vips::Image.new_from_file(path, **select_valid_loader_options(path, {}))
    end
  end
end