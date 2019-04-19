require 'test_helper'
require 'rack/mock'

class BobRossServerTest < Minitest::Test
  
  def create_store
    StandardStorage::Filesystem.new({
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
    
    # If resizing the image responses
    assert_equal 'Accept', server.get("/S100x100/opaque").headers['Vary']
    
    # If using format is specified in the URL no varying based on headers; will
    # always return format in url
    assert !server.get("/opaque.jpg").headers.has_key?('Vary')
    
    # If resizing the image
    assert !server.get("/S100x100/opaque.jpg").headers.has_key?('Vary')
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
    assert_equal 'image/png',  server.get("/transparent").headers['Content-Type']
    assert_equal 'image/webp', server.get("/opaque", {'HTTP_ACCEPT' => 'image/webp,image/*,*/*;q=0.8'}).headers['Content-Type']
  end
  
  test 'Responds with a 410 Gone when after expiration time' do
    server = create_server
    
    time = Time.now.to_i
    assert_equal 200, server.get("/E#{(time+10).to_s(16)}/opaque").status
    assert_equal 410, server.get("/E#{(time-10).to_s(16)}/opaque").status
  end

  test 'Responds with image auto oriented' do
    server = create_server({
      store: StandardStorage::Filesystem.new({
        path: File.expand_path('../../fixtures/images_with_orientations', __FILE__)
      })
    })
    
    Dir.mktmpdir do |tmpdir|
      1.upto(8) do |i|
        response = server.get("/landscape-#{i}.jpg")
        File.write(File.join(tmpdir, i.to_s + '.jpg'), response.body)
        command = Terrapin::CommandLine.new("identify", "-format '%[w]x%[h]' :file")
        assert_equal '600x450', command.run({ file: File.join(tmpdir, i.to_s + '.jpg') }), "landscape-#{i} no auto oriented"
        
        response = server.get("/portrait-#{i}.jpg")
        File.write(File.join(tmpdir, i.to_s + '.jpg'), response.body)
        command = Terrapin::CommandLine.new("identify", "-format '%[w]x%[h]' :file")
        assert_equal '450x600', command.run({ file: File.join(tmpdir, i.to_s + '.jpg') }), "portrait-#{i} no auto oriented"
      end
    end
  end

  test 'Responds with transformed image that is auto oriented' do
    server = create_server({
      store: StandardStorage::Filesystem.new({
        path: File.expand_path('../../fixtures/images_with_orientations', __FILE__)
      })
    })
    
    Dir.mktmpdir do |tmpdir|
      1.upto(8) do |i|
        response = server.get("/G/landscape-#{i}.jpg")
        File.write(File.join(tmpdir, i.to_s + '.jpg'), response.body)
        command = Terrapin::CommandLine.new("identify", "-format '%[w]x%[h]' :file")
        assert_equal '600x450', command.run({ file: File.join(tmpdir, i.to_s + '.jpg') }), "landscape-#{i} no auto oriented"
        
        response = server.get("/G/portrait-#{i}.jpg")
        File.write(File.join(tmpdir, i.to_s + '.jpg'), response.body)
        command = Terrapin::CommandLine.new("identify", "-format '%[w]x%[h]' :file")
        assert_equal '450x600', command.run({ file: File.join(tmpdir, i.to_s + '.jpg') }), "portrait-#{i} no auto oriented"
      end
    end
  end
  
  test 'if hmac present and hmac not configured'
  
  test 'asking for a watermark when not configured'
  
  test 'a PDF' do
    server = create_server
    
    response = server.get("/flyer")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['57721c8105857e29d9d18f27f445399f', '9d95b18af3bbad793d0b01427430d9e6'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S100/floorplan")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['919a4910d4e2afd36f0656ef86715ffe', 'fcab49d3d0ccaf2c1f1556efbcf03fc5'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S50x50/floorplan")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['e2ec209818d3bae17a98f39ade5947ec', 'ac726a807b0aa6d68b7a67d4baedc1e4'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/Sx50/flyer")
    File.write("/Users/malomalo/Code/bob_ross/test.jpg", response.body)
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['f0f80b815ddbbc6c681fbd1dc730dea0', 'b0f23188357ee09f7eb6448561cb6f69'], Digest::MD5.hexdigest(response.body)
  end
end