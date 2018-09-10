require 'socket'
require 'thread'
require File.expand_path('../../palette', __FILE__)


class BobRoss
  class PaletteServer

    STOP_COMMAND    = "?"
    HALT_COMMAND    = "!"

    attr_reader :palette
    
    def initialize(path, size = 1_073_741_824, host: '127.0.0.1', port: 8561)
      @host = host
      @port = port
      @palette = Palette.new(path, size)
      @check, @notify = IO.pipe
      @clients = []
      
      @connection = TCPServer.new(@host, @port)
    end
      
    def stop
      begin
        @notify << STOP_COMMAND
      rescue IOError
      end
    end
    
    def run
      @status = :run
      begin
        sockets = [@check, @connection]
        
        while @status == :run
          # begin
            ios = IO.select sockets
            ios.first.each do |sock|
            
              if sock == @check
                case @check.read(1)
                when STOP_COMMAND
                  @status = :stop
                  @clients.each(&:close)
                end
              else
                begin
                  if io = sock.accept_nonblock
                    client = Client.new(io, @palette)
                    Thread.start(client) do |c|
                      c.run
                      @clients.delete(c)
                    end
                    @clients << client
                  end
                rescue SystemCallError
                  # nothing
                rescue Errno::ECONNABORTED
                  # client closed the socket even before accept
                  begin
                    io.close
                  rescue
                  end
                end
              end
            
            end
          # rescue Object => e
          #   @events.unknown_error self, e, "Listen loop"
          # end
        end
      # rescue Exception => e
      #   STDERR.puts "Exception handling servers: #{e.message} (#{e.class})"
      #   STDERR.puts e.backtrace
      ensure
        begin
          @connection.close
        rescue
        end
      
        begin
          @check.close
        rescue
        end

        @notify.close
      end
    end
    
  end
end

class BobRoss::PaletteServer::Client
  
  def initialize(connection, palette)
    @open = true
    @palette = palette
    @connection = connection
    @semaphore = Mutex.new
  end
  
  def message(message, error = false)
    @connection.puts("#{error ? '-' : '+'}#{message}")
  end
  
  def close
    @semaphore.synchronize do
      message("QUIT")
    end
  end
  
  def run
    while @open
      command = @connection.gets
      if command.nil?
        @open = false
      else
        command = command.chomp.split(' ')
      
        @semaphore.synchronize do
          case command[0]
          when 'GET'
            if result = @palette.get(command[1])
              message("HIT #{result}")
            else
              message("+MISS")
            end
          when 'SET'
            @palette.set(command[1], command[2])
            message("OK")
          when 'DEL'
            @palette.del(command[1])
            message("OK")
          when 'QUIT'
            @open = false
            message("OK")
          else
            message("ERROR", true)
          end
        end
      end
    end
    @connection.close
  end
end



# GET key\n
#   MISS\n
#   HIT path\n
#
# SET key path
#   OK\n
#
# DEL key
#   OK\n