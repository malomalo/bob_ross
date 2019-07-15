require 'sqlite3'
require 'fileutils'

class BobRoss
  class Cache
  
    attr_reader :path, :max_size, :purge_to
    
    def initialize(path, cachefile, size: nil)
      @path = path
      @max_size = size || 1_073_741_824
      @db = SQLite3::Database.new(cachefile)
      @db.busy_timeout = 300
      migrate
    end
    
    def migrate
      tables = @db.execute(<<-SQL).flatten
        SELECT name FROM sqlite_master
        WHERE type='table'
        ORDER BY name;
      SQL

      if !tables.include?('transformations')
        @db.execute <<-SQL
          CREATE TABLE transformations (
            hash VARCHAR,
            transparent BOOLEAN,
            transform VARCHAR,

            size INTEGER,
            transformed_mime VARCHAR,
            transformed_at INTEGER,
            last_used_at INTEGER
          );
        SQL
        
        @db.execute <<-SQL
          CREATE UNIQUE INDEX thttm ON transformations (hash, transform, transformed_mime);
        SQL

        @db.execute <<-SQL
          CREATE INDEX tta ON transformations (transformed_at);
        SQL

        @db.execute <<-SQL
          CREATE TABLE stats (
            key VARCHAR,
            value INTEGER
          );
        SQL

        @db.execute <<-SQL
          INSERT INTO stats (key, value) VALUES ('size', 0);
        SQL

        @db.execute <<-SQL
          CREATE TRIGGER stats_trigger_a AFTER INSERT ON transformations
          FOR EACH ROW BEGIN
            UPDATE stats SET value = (value + new.size) WHERE stats.key = 'size';
          END
        SQL

        @db.execute <<-SQL
          CREATE TRIGGER stats_trigger_b AFTER DELETE ON transformations
          FOR EACH ROW BEGIN
            UPDATE stats SET value = (value - old.size) WHERE stats.key = 'size';
          END
        SQL
      end
    end
    
    def get(hash, transform)
      @db.execute(<<-SQL, hash, transform).to_a
        SELECT hash, transparent, transform, size, transformed_mime, transformed_at FROM transformations
        WHERE hash = ? AND transform = ?
      SQL
    rescue SQLite3::BusyException
    end
    
    def use(hash, transform, mime)
      @db.execute(<<-SQL, Time.now.to_i, hash, transform, mime)
        UPDATE transformations
        SET last_used_at = ?
        WHERE hash = ? AND transform = ? AND transformed_mime = ?;
      SQL
      
    rescue SQLite3::BusyException
    ensure
      return File.open(destination(hash, transform, mime))
    end
    
    def set(hash, transparent, transform, mime, path)
      stat = File.stat(path)
      dest = destination(hash, transform, mime)
      
      purge!(stat.size)
      
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(path, dest)
      @db.execute(<<-SQL, hash, transparent ? 1 : 0, transform, stat.size, mime, Time.now.to_i, Time.now.to_i)
        INSERT INTO transformations (hash, transparent, transform, size, transformed_mime, transformed_at, last_used_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      SQL
    rescue SQLite3::ConstraintException
      # Not unique because of index thttm, another thread probably already
      # generated the image, so we'll just continue and not bother copying over
      # another file
    rescue SQLite3::BusyException
      # Another thread is blocking us from inserting, remove image and continue
      FileUtils.rm(dest)
      nil
    rescue Errno::ENOSPC
      # Disk full, skip
    end

    def del(hash)
      entries = @db.execute(<<-SQL, hash).to_a
        SELECT hash, transform, transformed_mime FROM transformations
        WHERE hash = ?
      SQL
      
      entries.each do |entry|
        @db.execute(<<-SQL, entry[0], entry[1], entry[2])
          DELETE FROM transformations
          WHERE hash = ? AND transform = ? AND transformed_mime = ?
        SQL
        remove(entry[0], entry[1], entry[2])
      end
    end

    def size
      @db.execute("SELECT value FROM stats WHERE stats.key = 'size'").first&.first || 0
    end
    
    def purge!(buffer = 0)
      total_size = size
      new_size = total_size + buffer
      
      if new_size > @max_size
        puts "Cache filled (#{total_size} / #{@max_size})"
        purged = 0
        need_to_purge = new_size - @max_size
        while purged < need_to_purge
          r = @db.execute("SELECT hash, transform, transformed_mime, size FROM transformations ORDER BY last_used_at ASC LIMIT 1").first
          if r.nil?
            return
          else
            @db.execute(<<-SQL, r[0], r[1], r[2])
              DELETE FROM transformations
              WHERE hash = ? AND transform = ? AND transformed_mime = ?
            SQL

            remove(r[0], r[1], r[2])

            purged += r[3]
            puts " purged #{r[3]} (#{purged} / #{need_to_purge} purged)"
          end
        end
      end
    end

    def destination(hash, transform, mime)
      split = hash.scan(/.{1,4}/)
      split = split.shift(4).join("/") + split.join("")

      File.join(@path, [split, transform, mime.split('/').last].join('/'))
    end

    private
    
    def remove(hash, transform, mime)
      filename = destination(hash, transform, mime)
      FileUtils.rm(filename)
      
      # If there are alot of cache file the dirs take space and if they
      # are not removed could fill up the disk. Could come up with a way
      # to include these in the calculation (4k for folder, inode size 
      # 256), but for now at least remove empty directories
      dirname = File.dirname(filename)
      while dirname != @path && Dir.empty?(dirname)
        FileUtils.rmdir(dirname)
        dirname = File.dirname(dirname)
      end
    rescue Errno::ENOENT
    end
    
  end
end