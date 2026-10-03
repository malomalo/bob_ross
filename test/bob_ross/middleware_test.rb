# frozen_string_literal: true

require 'test_helper'
require 'rack/mock'
require 'rack/builder'
require 'rack/etag'
require 'rack/conditional_get'
require 'bob_ross/middleware'

class BobRossMiddlewareTest < Minitest::Test

  def create_server(configs={})
    BobRoss::Server.new({
      store: StandardStorage::Filesystem.new({
        path: File.expand_path('../../fixtures', __FILE__)
      })
    }.merge(configs))
  end

  # Stands in for the rest of a Rails stack: a session that rewrites its
  # cookie on every request, then Rack::ConditionalGet and Rack::ETag.
  def create_stack(**options)
    Rack::MockRequest.new(Rack::Builder.new {
      use BobRoss::Middleware, **options
      use(Class.new {
        def initialize(app) = @app = app
        def call(env)
          status, headers, body = @app.call(env)
          headers['set-cookie'] = '_session=abc; path=/'
          [status, headers, body]
        end
      })
      use Rack::ConditionalGet
      use Rack::ETag, 'no-cache'
      run ->(env) { [200, { 'content-type' => 'text/plain' }, ["app #{env['PATH_INFO']}"]] }
    }.to_app)
  end

  test 'serves requests under the prefix ahead of the rest of the stack' do
    stack = create_stack(server: create_server(cache_control: 'public, max-age=172800, immutable'))

    response = stack.get('/images/opaque')
    assert_equal 200, response.status
    assert_equal 'image/jpeg', response.headers['content-type']
    assert_equal 'public, max-age=172800, immutable', response.headers['cache-control']
    assert_nil response.headers['set-cookie']
  end

  test 'does not add cache-control when none is configured' do
    response = create_stack(server: create_server).get('/images/opaque')
    assert_equal 'image/jpeg', response.headers['content-type']
    assert_nil response.headers['cache-control']
  end

  test 'passes other requests on to the app' do
    stack = create_stack(server: create_server)

    %w[/ /imagesx/opaque /other/images/opaque].each do |path|
      response = stack.get(path)
      assert_equal "app #{path}", response.body
      assert_equal '_session=abc; path=/', response.headers['set-cookie']
    end
  end

  test 'moves the prefix from PATH_INFO to SCRIPT_NAME' do
    env = nil
    server = ->(e) { env = e; [200, {}, []] }
    stack = create_stack(prefix: '/media/', server: server)

    stack.get('/media/S10x10/opaque', 'SCRIPT_NAME' => '/root')
    assert_equal '/root/media', env['SCRIPT_NAME']
    assert_equal '/S10x10/opaque', env['PATH_INFO']
  end

  test 'resolves Proc prefix and server on the first request' do
    server = nil
    stack = create_stack(prefix: -> { '/images' }, server: -> { server })

    server = create_server
    assert_equal 'image/jpeg', stack.get('/images/opaque').headers['content-type']
  end

end
