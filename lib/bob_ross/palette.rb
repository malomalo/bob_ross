require 'fileutils'

class BobRoss
  class Palette
  
    attr_reader :path, :bytesize, :indexing, :purging, :maxbytesize, :purge_to
  
    def initialize(path, size = 1_073_741_824)
      @path = path
      @partition = true
      @partition_depth = 3
      @semaphore = Mutex.new

      @index = {}
      @indexing = false
      @bytesize = 0
      @maxbytesize = size
      @purging = false
      @purge_to = (@maxbytesize * 0.9).round
      
      FileUtils.mkdir_p(path)
      index
    end

    def index
      @semaphore.synchronize do
        if !@indexing
          @indexing = true
          Thread.new { index! }
        end
      end
    end
    
    def index!
      scan(@path) do |file|
        key = file.delete_prefix(@path).gsub('/', '')
        if !@index.has_key?(key)
          stat = File.stat(file)
          add_entry(Palette::Entry.new(key, stat.atime, stat.size))
        end
      end
      
      @indexing = false
    end
    
    def purge!
      run_purge = @semaphore.synchronize do
        if @purging
          false
        else
          @purging = true
        end
      end

      if run_purge
        Thread.new do
          @index.values.sort_by(&:timestamp).take_while do |entry|
            remove_entry(entry.key)
            @bytesize > @purge_to
          end
          @semaphore.synchronize { @purging = false }
        end
      end
    end
    
    def add_entry(entry)
      @semaphore.synchronize do
        if old_entry = @index[entry.key]
          @index[entry.key] = entry
          @bytesize += entry.bytesize
          @bytesize -= old_entry.bytesize
        else
          @index[entry.key] = entry
          @bytesize += entry.bytesize
        end
      end
      
      if @bytesize > @maxbytesize && !@purging
        purge!
      end
    end
    
    def remove_entry(key)
      @semaphore.synchronize do
        if entry = @index.delete(key)
          @bytesize -= entry.bytesize
        end
        entry
      end
    end
    
    def scan(dir, first_call: true, &block)
      Dir.children(dir).each do |child|
        child = File.join(dir, child)
        if File.directory?(child)
          scan(child, &block)
        else
          yield child
        end
      end
    end
    
    def get(key)
      dest = destination(key)
      
      if entry = @index[key]
        if File.exist?(dest)
          entry.timestamp = Time.now
          dest
        else
          remove_entry(key)
          nil
        end
      elsif @indexing
        if File.exist?(dest)
          stat = File.stat(dest)
          add_entry(Palette::Entry.new(key, stat.atime, stat.size))
          dest
        else
          nil
        end
      else
        nil
      end
    end

    def set(key, path)
      dest = destination(key)
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(path, dest)
    
      stat = File.stat(dest)
      add_entry(Palette::Entry.new(key, stat.atime, stat.size))
    end
    
    def del(key)
      if entry = remove_entry(key)
        FileUtils.rm(destination(key))
      end
    end

    # def fetch(key)
    #   file = get(key)
    #   if file.nil?
    #     file = yield
    #     set(key, file)
    #   end
    #   file
    # end
  
    def destination(key)
      File.join(@path, partition(key))
    end
  
    def partition(key)
      if @partition
        split = key.scan(/.{1,4}/)
        split.shift(@partition_depth).join("/") + split.join("")
      else
        key
      end
    end
  end
end

class BobRoss::Palette::Entry
  
  attr_accessor :key, :timestamp, :bytesize
  
  def initialize(key, timestamp, size)
    @key = key
    @timestamp = timestamp
    @bytesize = size
  end
  
end