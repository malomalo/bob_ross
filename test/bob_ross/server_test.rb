require 'test_helper'
require 'rack/mock'

class BobRossServerTest < Minitest::Test
  
  def create_store
    BobRoss::FileSystemStore.new({
      path: File.expand_path('../../fixtures', __FILE__)
    })
  end
  
  def create_server(configs={})
    configs[:store] ||= create_store
    Rack::MockRequest.new(BobRoss::Server.new(configs))
  end
  
  test 'Response Header: "Cache-Control"' do
    server = create_server
    assert !server.get("/opaque").headers.has_key?('Cache-Control')
        
    server = create_server(cache_control: 'public, max-age=172800, immutable')
    assert_equal 'public, max-age=172800, immutable', server.get("/opaque").headers['Cache-Control']
  end

  # Test also for Request Header DPR
  test 'Response Header: "Content-DPR"' do
    
    server = create_server
    
    # Default is 1; so don't include header on normal request
    assert !server.get("/opaque").headers.has_key?('Content-DPR')
    
    # Requesting a image with DPR 2, without resizing just returns like normal
    assert !server.get("/opaque", {'HTTP_DPR' => '2.0'}).headers.has_key?('Content-DPR')

    # Requesting a image with DPR 2, with resizing gets us an image w/that DPR
    assert_equal "2.0", server.get("/S100x100/opaque", {'HTTP_DPR' => '2.0'}).headers['Content-DPR']
  end
  
  test 'Response Header: "Content-Type"' do
    server = create_server
    
    assert_equal 'image/jpeg', server.get("/opaque").headers['Content-Type']
    assert_equal 'image/jpeg', server.get("/opaque.jpg").headers['Content-Type']
    assert_equal 'image/png', server.get("/opaque.png").headers['Content-Type']
    assert_equal 'image/webp', server.get("/opaque.webp").headers['Content-Type']
    
    
    assert_equal 'image/jpeg', server.get("/opaque", {'HTTP_ACCEPT' => 'image/jpeg'}).headers['Content-Type']
    assert_equal 'image/png', server.get("/opaque", {'HTTP_ACCEPT' => 'image/png'}).headers['Content-Type']
    assert_equal 'image/webp', server.get("/opaque", {'HTTP_ACCEPT' => 'image/webp'}).headers['Content-Type']
    
    assert_equal 'image/webp', server.get("/opaque", {'HTTP_ACCEPT' => 'image/webp,image/*,*/*;q=0.8'}).headers['Content-Type']
    assert_equal 'image/webp', server.get("/opaque", {'HTTP_ACCEPT' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'}).headers['Content-Type']
    assert_equal 'image/jpeg', server.get("/opaque", {'HTTP_ACCEPT' => 'image/*,*/*;q=0.8'}).headers['Content-Type']
    
    # Return a 415 Unsupported Media Type if we can't satisfy the Accept header
    assert_equal 415, server.get('/opaque', {'HTTP_ACCEPT' => 'image/magical'}).status
  end
  
  test 'Response Header: "Last-Modified" if last_modified_header' do
    store = create_store
    server = create_server(store: store, last_modified_header: true)
    
    time = Time.at(1487036461)
    store.stubs(:last_modified).returns(time)
    assert_equal 'Tue, 14 Feb 2017 01:41:01 GMT', server.get("/opaque").headers['Last-Modified']
  end

  test 'Response Header: "Last-Modified" set to if mutalbe' do
    store = create_store
    server = create_server(store: store, last_modified_header: false)
    
    time = Time.at(1487036461)
    store.stubs(:last_modified).returns(time)
    assert !server.get("/opaque").headers.has_key?('Last-Modified')
  end

  test 'Response Header: "Vary"' do
    server = create_server

    # If using Automatic Content Negotiation just reponses just vary on the
    # Accept header
    assert_equal 'Accept', server.get("/opaque").headers['Vary']
    
    # If resizing the image responses also dependon the DPR header
    assert_equal 'Accept, DPR', server.get("/S100x100/opaque").headers['Vary']
    
    # If using format is specified in the URL no varying based on headers; will
    # always return format in url
    assert !server.get("/opaque.jpg").headers.has_key?('Vary')
    
    # If resizing the image responses also dependon the DPR header
    assert_equal 'DPR', server.get("/S100x100/opaque.jpg").headers['Vary']
  end
  
  test 'Request Header: If-Modified-Since' do
    store = create_store
    server = create_server(store: store, last_modified_header: true)
    
    time = Time.at(1487036461)
    store.stubs(:last_modified).returns(time)
    
    # Return 200 OK with full response if modified
    assert_equal 200, server.get("/opaque", {"HTTP_IF_MODIFIED_SINCE" => (time-1).httpdate}).status

    # Return 304 Not Modified with full response if modified
    assert_equal 304, server.get("/opaque", {"HTTP_IF_MODIFIED_SINCE" => time.httpdate}).status
  end
  
  test 'Request Header: "Accept"; Automatic Content Negotiation' do
    server = create_server
    
    assert_equal 'image/jpeg', server.get("/opaque").headers['Content-Type']
    assert_equal 'image/png', server.get("/transparent").headers['Content-Type']
    assert_equal 'image/webp', server.get("/opaque", {'HTTP_ACCEPT' => 'image/webp,image/*,*/*;q=0.8'}).headers['Content-Type']
  end
  
  test 'Responds with a 410 Gone when after expiration time' do
    server = create_server
    
    time = Time.now.to_i
    assert_equal 200, server.get("/E#{(time+10).to_s(16)}/opaque").status
    assert_equal 410, server.get("/E#{(time-10).to_s(16)}/opaque").status
  end
  
  
end