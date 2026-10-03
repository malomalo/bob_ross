# frozen_string_literal: true

# Serves BobRoss from inside a Rack middleware stack, ahead of whatever comes
# after it. Requests under `prefix` go straight to the server; everything else
# is passed on to the next app.
#
# In Rails this is inserted right after ActionDispatch::Callbacks, so image
# requests skip cookies, the session, flash, CSP, Rack::Head,
# Rack::ConditionalGet and Rack::ETag. None of those apply to images and the
# session one rewrote the session cookie on every image response (when
# `expire_after` is set), which stops a CDN from caching it.
#
# `prefix` and `server` may be given as Procs; they are resolved on the first
# request. Rails builds its middleware stack before
# `after_initialize`, which is when the server can be built (the store is often
# an app constant).
class BobRoss::Middleware

  def initialize(app, prefix: '/images', server:)
    @app = app
    @prefix_option = prefix
    @server_option = server
  end

  def call(env)
    path = env['PATH_INFO']

    if path.start_with?(prefix) && (path.length == prefix.length || path[prefix.length] == '/')
      server.call(env.merge(
        'SCRIPT_NAME' => "#{env['SCRIPT_NAME']}#{prefix}",
        'PATH_INFO' => path.delete_prefix(prefix)
      ))
    else
      @app.call(env)
    end
  end

  def prefix
    @prefix ||= resolve(@prefix_option).chomp('/')
  end

  def server
    @server ||= resolve(@server_option)
  end

  private

  # A Proc is a deferred value; anything else is used as is.
  def resolve(value)
    value.is_a?(Proc) ? value.call : value
  end

end
