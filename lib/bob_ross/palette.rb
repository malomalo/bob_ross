require 'sqlite3'
require 'fileutils'

class BobRoss
  class Palette
  
    attr_reader :path, :size, :max_size, :purge_to
    
    def initialize(path, cachefile, size: 1_073_741_824)
      @path = path
      @max_size = size
      @db = SQLite3::Database.new(cachefile)
      migrate

      @purge_size = (@max_size * 0.05).round

      @insert = @db.prepare(<<-SQL)
        INSERT INTO transformations (hash, transparent, transform, size, transformed_mime, transformed_at)
        VALUES (?, ?, ?, ?, ?, ?)
      SQL

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
          
          CREATE UNIQUE INDEX thttm ON transformations (hash, transform, transformed_mime);
          CREATE INDEX tta ON transformations (transformed_at);
        SQL
      end
    end
    
    def get(hash, transform)
      @select.execute(hash, transform).to_a
    end
    
    def set(hash, transparent, transform, mime, path)
      dest = destination(hash, transform, mime)
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(path, dest)
    
      stat = File.stat(dest)
      @insert.execute(hash, transparent ? 1 : 0, transform, stat.size, mime, Time.now.to_i)
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
          @select = @db.execute(<<-SQL, r[0], r[1], r[2])
            DELETE FROM transformations
            WHERE hash = ? AND transform = ? AND transformed_mime = ?
          SQL
          FileUtils.rm(destination(r[0], r[1], r[2]))
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