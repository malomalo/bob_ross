# frozen_string_literal: true

require 'test_helper'
require 'open3'

# Boots a minimal Rails app in a separate process (Rails.application is
# global, and the railtie calls BobRoss.configure) and checks images are served
# from the middleware stack ahead of the session and Rack::ETag.
class BobRossRailtieTest < Minitest::Test

  APP = <<~'RUBY'
    require 'rails'
    require 'action_controller/railtie'
    require 'bob_ross'
    require 'bob_ross/railtie'
    require 'standard_storage'
    require 'standard_storage/filesystem'
    require 'rack/mock'

    class TestApp < Rails::Application
      config.root = Dir.mktmpdir
      config.eager_load = false
      config.logger = Logger.new(IO::NULL)
      config.secret_key_base = 'x' * 64
      config.hosts.clear
      config.session_store :cookie_store, key: '_test_session', expire_after: 2_592_000
      config.bob_ross.backend = ENV['BOBROSS_BACKEND'] || 'imagemagick'
      config.bob_ross.hmac.required = false
      config.bob_ross.server.cache = nil
      config.bob_ross.server.cache_control = 'public, max-age=172800, immutable'
      config.bob_ross.server.store = -> { StandardStorage::Filesystem.new(path: ENV['FIXTURES']) }
      config.bob_ross.server = nil if ENV['NO_SERVER']

      routes.append do
        get '/page', to: ->(env) {
          env['rack.session'][:seen] = true
          [200, { 'content-type' => 'text/plain' }, ['page']]
        }
      end
    end
    TestApp.initialize!

    stack = TestApp.middleware.map(&:klass)
    if ENV['NO_SERVER']
      puts Marshal.dump({ middleware_index: stack.map(&:name).index('BobRoss::Middleware'), server: TestApp.bob_ross_server }).unpack1('H*')
      exit
    end

    request = Rack::MockRequest.new(TestApp)
    page = request.get('/page')
    image = request.get('/images/opaque', 'HTTP_COOKIE' => page.headers['set-cookie'].split(';').first)

    puts Marshal.dump({
      middleware_index: stack.index(BobRoss::Middleware),
      callbacks_index: stack.index(ActionDispatch::Callbacks),
      cookies_index: stack.index(ActionDispatch::Cookies),
      routes: TestApp.routes.routes.map { |r| r.path.spec.to_s },
      page_set_cookie: page.headers['set-cookie'],
      status: image.status,
      content_type: image.headers['content-type'],
      cache_control: image.headers['cache-control'],
      set_cookie: image.headers['set-cookie'],
      content_security_policy: image.headers.key?('content-security-policy')
    }).unpack1('H*')
  RUBY

  def boot(env = {})
    out, err, status = Open3.capture3(
      { 'FIXTURES' => File.expand_path('../../fixtures', __FILE__) }.merge(env),
      RbConfig.ruby, '-I', File.expand_path('../../../lib', __FILE__), '-e', APP
    )
    assert status.success?, err
    Marshal.load([out.lines.last.strip].pack('H*'))
  end

  test 'serves images ahead of the session, CSP and Rack::ETag' do
    result = boot

    assert_equal result[:callbacks_index] + 1, result[:middleware_index]
    assert result[:middleware_index] < result[:cookies_index]
    assert result[:routes].none? { |r| r.start_with?('/images') }

    assert result[:page_set_cookie], 'the session should still work for the app'
    assert_equal 200, result[:status]
    assert_equal 'image/jpeg', result[:content_type]
    assert_equal 'public, max-age=172800, immutable', result[:cache_control]
    assert_nil result[:set_cookie]
    assert_equal false, result[:content_security_policy]
  end

  test 'does not add the middleware when the server is off' do
    result = boot('NO_SERVER' => '1')
    assert_nil result[:middleware_index]
    assert_nil result[:server]
  end

end
