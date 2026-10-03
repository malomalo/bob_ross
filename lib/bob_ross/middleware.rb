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
# `prefix` and `server` may be given as Procs that take no arguments; they are
# resolved on the first request. Rails builds its middleware stack before
# `after_initialize`, which is when the server can be built (the store is often
# an app constant).
class BobRoss::Middleware

  def initialize(app, prefix: '/images', server:)
    @app = app
    @prefix = prefix
    @server = server
  end

  def call(env)
    prefix, server = endpoint
    path = env['PATH_INFO']

    if server && path.start_with?(prefix) && (path.length == prefix.length || path[prefix.length] == '/')
      server.call(env.merge(
        'SCRIPT_NAME' => "#{env['SCRIPT_NAME']}#{prefix}",
        'PATH_INFO' => path.delete_prefix(prefix)
      ))
    else
      @app.call(env)
    end
  end

  private

  def endpoint
    @endpoint ||= [
      resolve(@prefix)&.chomp('/'),
      resolve(@server)
    ]
  end

  # A zero-arity Proc is a deferred value; anything else (including a lambda
  # Rack app taking `env`) is used as is.
  def resolve(value)
    value.is_a?(Proc) && value.arity == 0 ? value.call : value
  end

end
