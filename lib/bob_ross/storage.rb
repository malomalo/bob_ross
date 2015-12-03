class BobRoss
  class FileSystemStore

    # options, path & prefix
    def initialize(configs={})
      @configs = configs
      @configs[:prefix] ||= ''
    end
    
    def local?
      true
    end

    def url(path)
      "#{host}/#{partition(path)}"
    end

    def host
      "#{@configs[:host]}#{@configs[:prefix]}"
    end

    def destination(path)
      File.join(@configs[:path], @configs[:prefix], partition(path))
    end

    def exists?(path)
      File.exist?(destination(path))
    end

    def write(path, file, options={})
      path = destination(path)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, file.read)
    end

    def cp(source, destination)
      source = destination(source)

      FileUtils.cp(source, destination)
    end

    def read(key, &block)
      File.read(destination(key), &block)
    end

    def delete(path)
      FileUtils.rm(destination(path), force: true)
    end

    private

    def partition(value)
      return value unless @configs[:partition]
      split = value.scan(/.{4}/)
      split.shift(3).join("/") + split.join("")
    end
  
  end
end
