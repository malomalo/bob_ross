require 'json'

class BobRoss
  class VideoPlugin < BobRoss::Plugin

    class Movie
      
      def initialize(source_filename)
        @source = source_filename
      end
  
      def metadata
        @metadata if @metadata
    
        output = Terrapin::CommandLine.new('ffprobe', '-i :input -print_format json -show_format -show_streams -show_error').run({
            input: @source
        })
        @metadata = JSON.parse(output, symbolize_names: true)[:streams][0]
      end
  
      def duration
        metadata[:duration].to_f
      end
      
    end
    
    
    def self.mime_types
      [/\Avideo\/.*\z/]
    end
    
    def self.transformations
      { seek: 'F' }
    end

    def self.encode_transformation(key, value)
      case key
      when :seek
        'F' + value.to_s.downcase
      end
    end

    def self.extract_transformations(transformation_string)
      transformations = []
      
      while match = transformation_string.match(/\A([A-Z])([^A-Z]+)/)
        case match[1]
        when 'F'
          # 55 - 55 seconds
          # 0.2 - 0.2 seconds
          # 200ms - 200 milliseconds
          # 200000us - 200000 microseconds
          # 23.189s - 23.189 seconds
          if match[2] =~ /\A\d+(\.\d+)?(ms|us|s|%)?\z/
            transformations << { seek: match[2] }
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
      movie = Movie.new(original_file.path)
      
      transformations << [:seek, '5%'] if transformations.empty?
      
      args = '-i :input'
      transformations.each do |transform|
        case transform[0]
        when :seek
          if transform[1].is_a?(String) && transform[1].end_with?('%')
            percentage = transform[1].to_f / 100.0
            if percentage >= 1
              args = "-sseof :seek #{args} -update true"
              interpolations[:seek] = "-1s"
            else
              args << ' -ss :seek'
              interpolations[:seek] = "#{(movie.duration * percentage)}s"
            end
          else
            args << ' -ss :seek'
            interpolations[:seek] = transform[1]
          end
        end
      end
      
      args << ' -vframes 1 -y :output'
      Terrapin::CommandLine.new('ffmpeg', args).run(interpolations)

      screenshot
    end

  end
  
end

BobRoss.register_plugin(BobRoss::VideoPlugin)