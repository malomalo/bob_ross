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
  # config.bob_ross.hmac.attributes = [[:transformations, :hash, :format]]
  
  config.bob_ross.server = ActiveSupport::OrderedOptions.new
  # config.bob_ross.server.store = -> {} || Value
  config.bob_ross.server.prefix = "/images"
  # config.bob_ross.server.cache_control = 'public, max-age=172800, immutable'
  # config.bob_ross.server.last_modified_header = true
  # config.bob_ross.server.watermarks = 'public/watermarks' || [file, file]
  config.bob_ross.server.disk_limit = '4GB'
  config.bob_ross.server.memory_limit = '1GB'

  config.bob_ross.server.palette = ActiveSupport::OrderedOptions.new
    
  if ::Rails.env.to_s === 'production'
    config.bob_ross.server.palette.file = 'tmp/cache/bobross.cache'
    config.bob_ross.server.palette.path = 'tmp/cache/bobross'
    config.bob_ross.server.palette.size = 1.gigabyte
  end
  
  def configs(app)
    config = app.config.bob_ross#.to_h
    config = config.deep_merge(app.secrets[:bob_ross]) if app.secrets[:bob_ross]

    config.delete(:hmac) if config[:hmac].empty?

    if config[:server]
      config[:server][:hmac] = config[:hmac]
      if config[:server][:watermarks].is_a?(String)
        config[:server][:watermarks] = Dir.children(config[:server][:watermarks]).sort.map { |w|
          File.join(config[:server][:watermarks], w)
        }
      elsif !config[:server][:watermarks] && Dir.exists?('public/watermarks')
        config[:server][:watermarks] = Dir.children('public/watermarks').sort.map { |w|
          File.join('public/watermarks', w)
        }
      end

    end
    config
  end
  
  rake_tasks do |app|
    namespace :bob_ross do
      namespace :palette do
        desc "Purge old cached files from the Palette"
        task :purge do
          if config = configs(app).dig(:server, :palette)
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
    config = configs(app)
    
    client_configs = config.except(:server).deep_dup
    BobRoss.configure(client_configs)

    if config[:server]
      prefix = config[:server].delete(:prefix)
      if config[:server][:store].is_a?(Proc)
        config[:server][:store] = config[:server][:store].call
      end
      
      require 'bob_ross/server'
      app.bob_ross_server = BobRoss::Server.new(config[:server])
      app.routes.prepend do
        mount app.bob_ross_server => prefix
      end
    end
  end

end