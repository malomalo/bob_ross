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
      "#{host}#{partition(path)}"
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
      FileUtils.cp(file.path, path)
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
    
    def md5(path)
      OpenSSL::Digest.new('md5', File.read(destination(path))).hexdigest
    end
    
    def last_modified(path)
      File.mtime(destination(path))
    end
    
    def mime_type(path)
      command = Cocaine::CommandLine.new("identify", '--mime -b :file')
      command.run({ file: destination(path) }).split(';')[0]
    end

    private

    def partition(value)
      return value unless @configs[:partition]
      split = value.scan(/.{1,4}/)
      split.shift(@configs[:partition_depth] || 3).join("/") + split.join("")
    end
  
  end
end
