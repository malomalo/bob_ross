module Rails
  class Application
    
    attr_accessor :bob_ross, :bob_ross_server
    
  end
end

class BobRoss::Railtie < Rails::Railtie
  
  config.bob_ross = ActiveSupport::OrderedOptions.new
  
  # config.bob_ross.host = 

  config.bob_ross.hmac = ActiveSupport::OrderedOptions.new
  # config.bob_ross.hmac.key = secret
  # config.bob_ross.hmac.required = false
  # config.bob_ross.hmac.attributes = [[:transformations, :hash]]
  
  config.bob_ross.server = ActiveSupport::OrderedOptions.new
  # config.bob_ross.server.store = -> {} || Value
  config.bob_ross.server.prefix = "/images"
  # config.bob_ross.server.cache_control = 'public, max-age=172800, immutable'
  config.bob_ross.server.last_modified_header = false
  config.bob_ross.server.watermarks = 'public/watermarks'# || [file, file]
  config.bob_ross.server.disk_limit = '4GB'
  config.bob_ross.server.memory_limit = '1GB'

  config.bob_ross.server.palette = ActiveSupport::OrderedOptions.new
    
  if ::Rails.env.to_s != 'production'
    config.bob_ross.server.palette.file = 'tmp/cache/bobross.cache'
    config.bob_ross.server.palette.path = 'tmp/cache/bobross'
    config.bob_ross.server.palette.size = 1.gigabyte
  end
  
  def initialize_configs(app)
    config = app.config.bob_ross
    
    if seekrets = app.secrets[:bob_ross]
      config.host = seekrets[:host] if seekrets[:host]
      
      if seekrets[:hmac].is_a?(String)
        config.hmac.key = seekrets[:hmac]
      else
        config.hmac.key = seekrets[:hmac][:key] if seekrets[:hmac][:key]
        config.hmac.required = seekrets[:hmac][:required] if seekrets[:hmac][:required]
        config.hmac.attributes = seekrets[:hmac][:attributes] if seekrets[:hmac][:attributes]
      end
      
      if seekrets[:server]
        config.server.prefix = seekrets[:server][:prefix] if seekrets[:server][:prefix]
        config.server.cache_control = seekrets[:server][:cache_control] if seekrets[:server][:cache_control]
        config.server.last_modified_header = seekrets[:server][:last_modified_header] if seekrets[:server][:last_modified_header]
        config.server.watermarks = seekrets[:server][:watermarks] if seekrets[:server][:watermarks]
        config.server.disk_limit = seekrets[:server][:disk_limit] if seekrets[:server][:disk_limit]
        config.server.memory_limit = seekrets[:server][:memory_limit] if seekrets[:server][:memory_limit]
        
        if seekrets[:server][:palette]
          config.server.palette.file = seekrets[:server][:palette][:file] if seekrets[:server][:palette][:file]
          config.server.palette.path = seekrets[:server][:palette][:path] if seekrets[:server][:palette][:path]
          config.server.palette.size = seekrets[:server][:palette][:size] if seekrets[:server][:palette][:size]
        end
      end
    end
    
    config.server.hmac = config.hmac
    config.server.store = config.server[:store].call if config.server[:store].is_a?(Proc)
    if config.server.watermarks.is_a?(String)
      if Dir.exists?(config.server.watermarks)
        config.server.watermarks = Dir.children(config.server.watermarks).sort.map { |w|
          File.join(config.server.watermarks, w)
        }
      end
    end
  end
  
  rake_tasks do |app|
    namespace :bob_ross do
      namespace :palette do
        desc "Purge old cached files from the Palette"
        task :purge do
          initialize_configs(app)
          if config = app.config.bob_ross.server.palette
            require 'bob_ross/palette'

            BobRoss::Palette.new(
              config[:path],
              config[:file],
              size: config[:size]
            ).purge!
          end
        end
      end
    end
  end
  
  config.after_initialize do |app|
    initialize_configs(app)
    config = app.config.bob_ross
    
    BobRoss.configure(config.except(:server))

    if config.server
      require 'bob_ross/server'
      app.bob_ross_server = BobRoss::Server.new(config.server.except(:prefix))
      app.routes.prepend do
        mount app.bob_ross_server => config.server.prefix
      end
    end
  end

end