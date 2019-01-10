class BobRoss
  class PDFPlugin < BobRoss::Plugin

    def self.mime_types
      ['application/pdf']
    end
  
    def self.encode_transformations(key, value)
      case key
      when :pages
        'R' + value.downcase
      end
    end
  
    def self.extract_options(transformations, key, value)
      case key
      when 'R'.freeze
        # "*", "1,4", "1,5,10-15", "3"
        transformations[:pages] = value
      end
    end
  
    def self.transform(original_file, transformations)
      screenshot = Tempfile.create(['preview', '.png'], binmode: true)
      size = transformations[:resize] ? parse_geometry(transformations[:resize]) : nil
    
      args = 'draw'
      args << ' -h :height' if size && size[:height]
      args << ' -w :width' if size && size[:width]
      args << ' -o :output :input'
      args << if transformations[:pages].nil?
        ' 1'
      elsif transformations[:pages] != '*'
        ' :pages'
      end
    
      Terrapin::CommandLine.new('mutool', args).run({
          input: original_file.path,
          output: screenshot.path,
          height: size && size[:height],
          width: size && size[:width],
          pages: transformations[:pages]
      })
    
      screenshot
    end

  end
end

BobRoss.register_plugin(BobRoss::PDFPlugin)