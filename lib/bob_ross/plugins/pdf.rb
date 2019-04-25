class BobRoss
  class PDFPlugin < BobRoss::Plugin

    def self.mime_types
      ['application/pdf']
    end
    
    def self.transformations
      { pages: 'R' }
    end
  
    def self.encode_transformation(key, value)
      case key
      when :pages
        'R' + value.downcase
      end
    end
  
    def self.extract_options(string)
      options = {}
      return options unless string

      string.scan(/([A-Z])([^A-Z]*)/) do |key, value|
        case key
        when 'R'.freeze
          # "*", "1,4", "1,5,10-15", "3"
          options[:pages] = value
        end
      end

      options
    end
  
    def self.transform(original_file, transformation_string, transformations)
      screenshot = Tempfile.create(['preview', '.png'], binmode: true)
      first_resize = transformations.find { |t| t[:resize] }
      size = first_resize ? parse_geometry(first_resize) : nil
      options = extract_options(transformation_string)
      
      args = 'draw'
      args << ' -h :height' if size && size[:height]
      args << ' -w :width' if size && size[:width]
      args << ' -o :output :input'
      args << if options[:pages].nil?
        ' 1'
      elsif options[:pages] != '*'
        ' :pages'
      else
        ''
      end
    
      Terrapin::CommandLine.new('mutool', args, expected_outcodes: [0, 1]).run({
          input: original_file.path,
          output: screenshot.path,
          height: size && size[:height],
          width: size && size[:width],
          pages: options[:pages]
      })
    
      screenshot
    end

  end
end

BobRoss.register_plugin(BobRoss::PDFPlugin)