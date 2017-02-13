require 'test_helper'
require 'rack/mock'

class BobRossServerTest < Minitest::Test
  
  def store
    BobRoss::FileSystemStore.new({
      path: File.expand_path('../../fixtures', __FILE__)
    })
  end
  
  test 'cache_control' do
    server =  Rack::MockRequest.new(BobRoss::Server.new({
      cache_control: 'public, max-age=172800, immutable',
      store: store
    }))
    
    assert_equal 'public, max-age=172800, immutable', server.get("/opaque").headers['Cache-Control']
  end
  
  test 'automatic content negotiation' do
    server = Rack::MockRequest.new(BobRoss::Server.new(store: store))
    
    assert_equal 'image/jpeg', server.get("/opaque").headers['Content-Type']
    assert_equal 'image/png', server.get("/transparent").headers['Content-Type']
    assert_equal 'image/webp', server.get("/opaque", {'HTTP_ACCEPT' => 'image/webp,image/*,*/*;q=0.8'}).headers['Content-Type']
  end
  
  test 'DPR support' do
    server = Rack::MockRequest.new(BobRoss::Server.new(store: store))
    
    assert_nil server.get("/opaque").headers['DPR']
    assert_nil server.get("/opaque", {'HTTP_DPR' => '2.0'}).headers['Content-DPR']
    assert_equal '2.0', server.get("/S100x100/opaque", {'HTTP_DPR' => '2.0'}).headers['Content-DPR']
    #TODO: test, don't resize if image smaller than resize???
  end
  
end