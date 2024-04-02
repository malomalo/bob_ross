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
  config.bob_ross.hmac.transformations = ActiveSupport::OrderedOptions.new
  # config.bob_ross.hmac.transforms.optional = [:resize]
  
  config.bob_ross.server = ActiveSupport::OrderedOptions.new
  config.bob_ross.backend = 'imagemagick'
  # config.bob_ross.server.store = -> {} || Value
  config.bob_ross.server.prefix = "/images"
  # config.bob_ross.server.cache_control = 'public, max-age=172800, immutable'
  config.bob_ross.server.last_modified_header = false
  config.bob_ross.server.watermarks = Dir.exist?('public/watermarks') ? 'public/watermarks' : nil # || [file, file]
  config.bob_ross.server.disk_limit = '4GB'
  config.bob_ross.server.memory_limit = '1GB'

  config.bob_ross.server.cache = ActiveSupport::OrderedOptions.new
    
  if ::Rails.env.to_s != 'production'
    FileUtils.mkdir_p('tmp/cache/bobross')
    config.bob_ross.server.cache.file = 'tmp/cache/bobross.cache'
    config.bob_ross.server.cache.path = 'tmp/cache/bobross'
    config.bob_ross.server.cache.size = 1_073_741_824 # 1GB
  end
  
  def initialize_configs(app)
    config = app.config.bob_ross
    
    if seekrets = app.credentials[:bob_ross] || app.secrets[:bob_ross]
      config.host = seekrets[:host] if seekrets[:host]
      config.backend = seekrets[:backend] if seekrets[:backend]
      
      if seekrets[:hmac].is_a?(String)
        config.hmac.key = seekrets[:hmac]
      elsif seekrets[:hmac]
        config.hmac.key = seekrets[:hmac][:key] if seekrets[:hmac][:key]
        config.hmac.required = seekrets[:hmac][:required] if seekrets[:hmac].has_key?(:required)
        config.hmac.attributes = seekrets[:hmac][:attributes] if seekrets[:hmac][:attributes]
        config.hmac.transformations.optional = seekrets[:hmac][:transformations][:optional] if seekrets[:hmac][:transformations]
      end
      
      if seekrets[:server]
        config.server.prefix = seekrets[:server][:prefix] if seekrets[:server][:prefix]
        config.server.cache_control = seekrets[:server][:cache_control] if seekrets[:server][:cache_control]
        config.server.last_modified_header = seekrets[:server][:last_modified_header] if seekrets[:server][:last_modified_header]
        config.server.watermarks = seekrets[:server][:watermarks] if seekrets[:server][:watermarks]
        config.server.disk_limit = seekrets[:server][:disk_limit] if seekrets[:server][:disk_limit]
        config.server.memory_limit = seekrets[:server][:memory_limit] if seekrets[:server][:memory_limit]
        
        if seekrets[:server][:cache] == false
          config.server.cache = nil
        elsif seekrets[:server][:cache] && Dir.exist?(seekrets[:server][:cache][:path]) && Dir.exist?(File.dirname(seekrets[:server][:cache][:file]))
          config.server.cache.file = seekrets[:server][:cache][:file] if seekrets[:server][:cache][:file]
          config.server.cache.path = seekrets[:server][:cache][:path] if seekrets[:server][:cache][:path]
          config.server.cache.size = seekrets[:server][:cache][:size] if seekrets[:server][:cache][:size]
        end
      end
    end
    
    if config.server
      config.server.hmac = config.hmac.dup
      config.server.hmac.attributes = config.server.hmac.attributes.dup
      if config.hmac.attributes.is_a?(Array) && config.hmac.attributes.first.is_a?(Array)
        config.hmac.attributes = config.hmac.attributes.first
      end
      
      if config.server.watermarks.is_a?(String)
        if Dir.exist?(config.server.watermarks)
          config.server.watermarks = Dir.children(config.server.watermarks).sort.map { |w|
            File.join(config.server.watermarks, w)
          }
        else
          config.server.watermarks = nil
        end
      end
    end
    
    if !config.logger
      config.logger = Rails.logger
      config.server.logger = Rails.logger if config.server
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
  
  server do |app|
    # Do this here instead of in after_initialize because the Proc may call
    # ActiveRecord and this might cause things like db:create to fail because
    # it looks for the Store first
    if app.bob_ross_server.settings[:store].is_a?(Proc)
      app.bob_ross_server.settings[:store] = app.bob_ross_server.settings[:store].call
    end
  end

end
