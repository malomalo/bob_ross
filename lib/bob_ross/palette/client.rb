require 'uri'

class BobRoss
  class PaletteClient
      
    def initialize(host = '127.0.0.1:8561')
      uri = URI.parse(host)
      @host = uri.host
      @port = uri.port
      @socket = TCPSocket.open(uri.host, uri.port)
    end
      
    def send(command)
      @socket.puts(command)
      ret = @socket.gets.chomp
      if ret.start_with?('-')
        ret.delete_prefix!('-')
        raise ret
      else
        ret.delete_prefix!('+').split(' ')
      end
    end
    
    def get(key)
      ret = send("GET #{key}")
      if ret[0] == 'HIT'
        ret[1]
      else
        nil
      end
    end
    
    def set(key, path)
      send("SET #{key} #{path}")
    end
    
    def del(key)
      send("DEL #{key}")
    end
      
  end
end