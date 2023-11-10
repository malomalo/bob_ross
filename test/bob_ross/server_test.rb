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
    assert_equal 'image/png', server.get("/opaque",  {'HTTP_ACCEPT' => 'image/png'}).headers['Content-Type']
    assert_equal 'image/webp', server.get("/opaque", {'HTTP_ACCEPT' => 'image/webp'}).headers['Content-Type']
    
    assert_equal 'image/webp', server.get("/opaque", {'HTTP_ACCEPT' => 'image/webp,image/*,*/*;q=0.8'}).headers['Content-Type']
    assert_equal 'image/webp', server.get("/opaque", {'HTTP_ACCEPT' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'}).headers['Content-Type']
    assert_equal 'image/jpeg', server.get("/opaque", {'HTTP_ACCEPT' => 'image/*,*/*;q=0.8'}).headers['Content-Type']

    # Apple wants pngs more than any other image, but we wanna save bandwidth,
    # we want to send jpg in this situation
    assert_equal 'image/jpeg', server.get("/opaque", {'HTTP_ACCEPT' => 'image/png,image/svg+xml,image/*;q=0.8,video/*;q=0.8,*/*;q=0.5'}).headers['Content-Type']
    
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
  
  test 'if hmac is required and not correct responds with a 404' do
    server = create_server({ hmac: 'key' })
    assert_equal 404, server.get('/opaque').status
    assert_equal 200, server.get('/H46db1285b6f7a2cf96f4b7e012c8a6ba34fc4bcf/opaque').status
  end
  
  test 'optional tranformations are not required for hmac' do
    server = create_server({ hmac: {
      key: 'key',
      attributes: [[:transformations]],
      transformations: { optional: [ :resize ] }
    }})
    
    assert_equal 404, server.get('/opaque').status
    assert_equal 404, server.get('/S100x100/opaque').status
    assert_equal 200, server.get('/H4e4df0e870d9566c290b68f30d602f3b4559a7a5S100x100/opaque').status
    assert_equal 200, server.get('/Hf42bb0eeb018ebbd4597ae7213711ec60760843fS100x100/opaque').status
    assert_equal 404, server.get('/Hthisisawronghmacitshouldreturna404whenseS100x100/opaque').status
  end
  
  test 'if hmac present and hmac not configured'
  
  test 'asking for a watermark when not configured'
  
  test 'a PDF' do
    server = create_server
    
    response = server.get("/flyer")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['0bfb297897f6f5cb3395105745fd35a0', 'e35901e7be8d4ce03a0b7b94da8e8778'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S100/floorplan")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['0f3ce776621680da230e625554aa5372', 'ebc5b062a01c0a957bf2edf8d2a34244'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S50x50/floorplan")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['f50d18da6bd6a86952cf4bad797553ec', '466df5bff4883d22f022bc77a7497481'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/Sx50/flyer")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['8db654d754f9c7e584669f4cb75f57ad', '4a62e849f803ab865d8d3ae4a8f777cf'], Digest::MD5.hexdigest(response.body)
  end
  
  test 'a Video' do
    server = create_server
    
    response = server.get("/video")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['53a4df2f7588fe954f2dcc57d6b8bab8', 'd3d0ffa9b1dd870594b6af2dabb782b8'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S100/video")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['2303a1cb94aed6e5889ed082071c52d5', '205cbdf7daea9af314a0685e036a389f'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S50x50/video")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['ed50d0301a8f5c6029154a084a1f4eb7', '6005e29dd99b8561c6253c5868582b5c'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/Sx50/video")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['a6055e4f8356c833dde52d4daa9f5570', '97af57afe70815f6a459275600fba1a9'], Digest::MD5.hexdigest(response.body)
  end
end