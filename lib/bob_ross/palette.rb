require 'sqlite3'
require 'fileutils'

class BobRoss
  class Palette
  
    attr_reader :path, :size, :max_size, :purge_to
    
    def initialize(path, cachefile, size: 1_073_741_824)
      @path = path
      @max_size = size
      @db = SQLite3::Database.new(cachefile)
      @db.busy_timeout = 100
      migrate

      @purge_size = (@max_size * 0.05).round

      @select = @db.prepare(<<-SQL)
        SELECT hash, transparent, transform, size, transformed_mime, transformed_at FROM transformations
        WHERE hash = ? AND transform = ?
      SQL
    end
    
    def migrate
      tables = @db.execute(<<-SQL).flatten
        SELECT name FROM sqlite_master
        WHERE type='table'
        ORDER BY name;
      SQL

      if !tables.include?('transformations')
        @db.execute <<-SQL
          create table transformations (
            hash VARCHAR,
            transparent BOOLEAN,
            transform VARCHAR,
            size INTEGER,
            transformed_mime VARCHAR,
            transformed_at INTEGER
          );
        SQL
      end
      
      @db.execute <<-SQL
        CREATE UNIQUE INDEX IF NOT EXISTS thttm ON transformations (hash, transform, transformed_mime);
      SQL
      
      @db.execute <<-SQL
        CREATE INDEX IF NOT EXISTS tta ON transformations (transformed_at);
      SQL
    end
    
    def get(hash, transform)
      @select.execute(hash, transform).to_a
    end
    
    def set(hash, transparent, transform, mime, path)
      stat = File.stat(path)
      dest = destination(hash, transform, mime)
      
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(path, dest)
      @db.execute(<<-SQL, hash, transparent ? 1 : 0, transform, stat.size, mime, Time.now.to_i)
        INSERT INTO transformations (hash, transparent, transform, size, transformed_mime, transformed_at)
        VALUES (?, ?, ?, ?, ?, ?)
      SQL
    rescue SQLite3::ConstraintException
      # Not unique because of index thttm, another thread probably already
      # generated the image, so we'll just continue and not bother copying over
      # another file
    end

    def size
      @db.execute("SELECT SUM(size) FROM transformations").first&.first || 0
    end
    
    def purge!
      total_size = size
      if total_size > @max_size
        purged = 0
        need_to_purge = total_size - (@max_size - @purge_size)
        while purged < need_to_purge
          r = @db.execute("SELECT hash, transform, transformed_mime, size FROM transformations ORDER BY transformed_at ASC LIMIT 1").first
          @db.execute(<<-SQL, r[0], r[1], r[2])
            DELETE FROM transformations
            WHERE hash = ? AND transform = ? AND transformed_mime = ?
          SQL
          begin
            FileUtils.rm(destination(r[0], r[1], r[2]))
          rescue Errno::ENOENT
          end
          purged += r[3]
        end
      end
    end

    def destination(hash, transform, mime)
      split = hash.scan(/.{1,4}/)
      split = split.shift(4).join("/") + split.join("")

      File.join(@path, [split, transform, mime.split('/').last].join('/'))
    end

  end
end