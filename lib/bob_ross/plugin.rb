# frozen_string_literal: true

class BobRoss::Plugin

  def self.transformations
    {}
  end
  
  def self.encode_transformation(key, value)
  end

  def self.extract_transformations(transformation_string)
    []
  end

  def self.parse_geometry(string)
    string =~ /^(\d+)?(?:x(\d+))?([+-]\d+)?([+-]\d+)?.*$/
  
    {
      width: $1 ? $1.to_i : nil,
      height: $2 ? $2.to_i : nil,
      x_offset: $3 ? $3.to_i : nil,
      y_offset: $4 ? $4.to_i : nil
    }
  end

end