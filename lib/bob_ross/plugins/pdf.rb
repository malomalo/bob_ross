class BobRoss
  class PDFPlugin < BobRoss::Plugin

    def self.mime_types
      ['application/pdf']
    end
    
    def self.transformations
      { page: 'R' }
    end
  
    def self.encode_transformation(key, value)
      case key
      when :page
        'R' + value.to_s.downcase
      end
    end
  
    def self.extract_transformations(transformation_string)
      transformations = []
      
      while match = transformation_string.match(/\A([A-Z])([^A-Z]+)/)
        case match[1]
        when 'R'
          # 3 - Page 3
          if match[2] =~ /\A\d+\z/
            transformations << [:page, match[2]]
          else
            break
          end
        else
          break
        end
        transformation_string.delete_prefix!(match[0])
      end
      
      transformations
    end
  
    def self.transform(original_file, transformations=[], ross_transformations=[])
      screenshot = Tempfile.create(['preview', '.png'], binmode: true)
      interpolations = { input: original_file.path, output: screenshot.path }
      
      args = 'draw'
      
      if first_resize = ross_transformations.find { |t| t[0] == :resize }
        size = parse_geometry(first_resize[1])
        if size[:height]
          args << ' -h :height'
          interpolations[:height] = size[:height]
        end
        if size[:width]
          args << ' -w :width'
          interpolations[:width] = size[:width]
        end
      end
      
      transformations << [:page, 1] if transformations.empty?
      transformations.each do |transform|
        case transform[0]
        when :page
          args << ' -o :output :input :page'
          interpolations[:page] = transform[1]
        end
      end
      
      Terrapin::CommandLine.new('mutool', args).run(interpolations)
      screenshot
    end

  end
end

BobRoss.register_plugin(BobRoss::PDFPlugin)