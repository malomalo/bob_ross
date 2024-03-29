require 'test_helper'
require 'rack/mock'

class BobRossServerWithCacheTest < Minitest::Test
  
  def setup
    @cache_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry @cache_dir
  end
  
  def create_store
    StandardStorage::Filesystem.new({
      path: File.expand_path('../../fixtures', __FILE__)
    })
  end
  
  def create_server(configs={})
    configs[:store] ||= create_store
    configs[:cache] ||= BobRoss::Cache.new(@cache_dir, File.join(@cache_dir, 'bobross.cache'))
    Rack::MockRequest.new(BobRoss::Server.new(configs))
  end
  
  def cache_test
    yield("0")
    yield("1")
  end
  
  test 'Response Header: "Cache-Control"' do
    server = create_server
    response = server.get("/opaque")
    assert !response.headers.has_key?('Cache-Control')
    assert_equal "0", response.headers['From-Cache']
    
    response = server.get("/opaque")
    assert_equal "1", response.headers['From-Cache']
    
    server = create_server(cache_control: 'public, max-age=172800, immutable')
    response = server.get("/opaque")
    assert_equal 'public, max-age=172800, immutable', response.headers['Cache-Control']
    assert_equal "1", response.headers['From-Cache']
  end

  test 'Response Header: "Content-Type"' do
    server = create_server
    
    cache_test do |r|
      response = server.get("/opaque")
      assert_equal 'image/jpeg', response.headers['Content-Type']
      assert_equal r, response.headers['From-Cache']
    end
    
    response = server.get("/opaque.jpg")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_equal "1", response.headers['From-Cache']
    
    cache_test do |r|
      response = server.get("/opaque.png")
      assert_equal 'image/png', response.headers['Content-Type']
      assert_equal r, response.headers['From-Cache']
    end
    
    cache_test do |r|
      response = server.get("/opaque.webp")
      assert_equal 'image/webp', response.headers['Content-Type']
      assert_equal r, response.headers['From-Cache']
    end
    
    response = server.get("/opaque", {'HTTP_ACCEPT' => 'image/jpeg'})
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_equal '1', response.headers['From-Cache']
    
    response = server.get("/opaque", {'HTTP_ACCEPT' => 'image/png'})
    assert_equal 'image/png', response.headers['Content-Type']
    assert_equal "1", response.headers['From-Cache']
    
    response = server.get("/opaque", {'HTTP_ACCEPT' => 'image/webp'})
    assert_equal 'image/webp', response.headers['Content-Type']
    assert_equal "1", response.headers['From-Cache']
    
    response = server.get("/opaque", {'HTTP_ACCEPT' => 'image/webp,image/*,*/*;q=0.8'})
    assert_equal 'image/webp', response.headers['Content-Type']
    assert_equal "1", response.headers['From-Cache']
    
    response = server.get("/opaque", {'HTTP_ACCEPT' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'})
    assert_equal 'image/webp', response.headers['Content-Type']
    assert_equal "1", response.headers['From-Cache']

    response = server.get("/opaque", {'HTTP_ACCEPT' => 'image/*,*/*;q=0.8'})
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_equal "1", response.headers['From-Cache']
    
    # Return a 415 Unsupported Media Type if we can't satisfy the Accept header
    cache_test do |r|
      assert_equal 415, server.get('/opaque', {'HTTP_ACCEPT' => 'image/magical'}).status
    end
  end
  
  test 'Response Header: "Last-Modified" if last_modified_header' do
    store = create_store
    server = create_server(store: store, last_modified_header: true)
    
    time = Time.at(1487036461)
    store.stubs(:last_modified).returns(time)
    cache_test do |r|
      assert_equal 'Tue, 14 Feb 2017 01:41:01 GMT', server.get("/opaque").headers['Last-Modified']
    end
  end

  test 'Response Header: "Last-Modified" set to if mutalbe' do
    store = create_store
    server = create_server(store: store, last_modified_header: false)
    
    time = Time.at(1487036461)
    store.stubs(:last_modified).returns(time)
    cache_test do |r|
      assert !server.get("/opaque").headers.has_key?('Last-Modified')
    end
  end

  test 'Response Header: "Vary"' do
    server = create_server

    # If using Automatic Content Negotiation just reponses just vary on the
    # Accept header
    cache_test do |r|
      assert_equal 'Accept', server.get("/opaque").headers['Vary']
    end
    
    # If resizing the image
    cache_test do |r|
      assert_equal 'Accept', server.get("/S100x100/opaque").headers['Vary']
    end
    
    # If using format is specified in the URL no varying based on headers; will
    # always return format in url
    cache_test do |r|
      assert !server.get("/opaque.jpg").headers.has_key?('Vary')
    end
    
    # If resizing the image
    cache_test do |r|
      assert !server.get("/S100x100/opaque.jpg").headers.has_key?('Vary')
    end
  end
  
  test 'Request Header: If-Modified-Since' do
    store = create_store
    server = create_server(store: store, last_modified_header: true)
    
    time = Time.at(1487036461)
    store.stubs(:last_modified).returns(time)
    
    # Return 200 OK with full response if modified
    cache_test do |r|
      assert_equal 200, server.get("/opaque", {"HTTP_IF_MODIFIED_SINCE" => (time-1).httpdate}).status
    end

    # Return 304 Not Modified with full response if modified
    cache_test do |r|
      assert_equal 304, server.get("/opaque", {"HTTP_IF_MODIFIED_SINCE" => time.httpdate}).status
    end
  end
  
  test 'Request Header: "Accept"; Automatic Content Negotiation' do
    server = create_server

    cache_test do |r|
      response = server.get("/opaque")
      assert_equal 'image/jpeg', response.headers['Content-Type']
      assert_equal r, response.headers['From-Cache']
    end
    cache_test do |r|
      response = server.get("/transparent")
      assert_equal 'image/png', response.headers['Content-Type']
      assert_equal r, response.headers['From-Cache']
    end
    cache_test do |r|
      response = server.get("/opaque", {'HTTP_ACCEPT' => 'image/webp,image/*,*/*;q=0.8'})
      assert_equal 'image/webp', response.headers['Content-Type']
      assert_equal r, response.headers['From-Cache']
    end
  end
  
  test 'Responds with a 410 Gone when after expiration time' do
    server = create_server
    
    time = Time.now.to_i
    cache_test do |r|
      assert_equal 200, server.get("/E#{(time+10).to_s(16)}/opaque").status
    end
    cache_test do |r|
      assert_equal 410, server.get("/E#{(time-10).to_s(16)}/opaque").status
    end
  end
  
  test 'if hmac present and hmac not configured'
  
  test 'asking for a watermark when not configured'
  
  test 'transforming an image' do
    server = create_server

    response = server.get("/opaque")
    response = server.get("/opaque")
    assert_equal "1", response.headers['From-Cache']

    response = server.get("D/opaque")
    assert_equal "0", response.headers['From-Cache']
    
    response = server.get("Q70/opaque")
    response = server.get("Q70/opaque")
    assert_equal "1", response.headers['From-Cache']

    large_image_size = response.body.bytesize
    response = server.get("Q40/opaque")
    assert response.body.bytesize < large_image_size
    assert_equal "0", response.headers['From-Cache']

    response = server.get("Q40/opaque")
    assert response.body.bytesize < large_image_size
    assert_equal "1", response.headers['From-Cache']
  end
  
  test 'a PDF' do
    server = create_server

    cache_test do |r|
      assert_equal r, server.get("/flyer").headers['From-Cache']
    end

    cache_test do |r|
      assert_equal r, server.get("/S100/floorplan").headers['From-Cache']
    end

    cache_test do |r|
      assert_equal r, server.get("/S50x50/floorplan").headers['From-Cache']
    end
    
    cache_test do |r|
      assert_equal r, server.get("/Sx50/flyer").headers['From-Cache']
    end
  end
end