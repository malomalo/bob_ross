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
  
  test 'Response Header: "Content-Type" for various browser Accept Headers' do
    server = create_server
    
    # Firefox 92 and later
    assert_equal 'image/avif', server.get("/opaque", {'HTTP_ACCEPT' => 'image/avif,image/webp,*/*'}).headers['Content-Type']
    assert_equal 'image/avif', server.get("/transparent", {'HTTP_ACCEPT' => 'image/avif,image/webp,*/*'}).headers['Content-Type']

    # Firefox 65 to 91
    assert_equal 'image/webp', server.get("/opaque", {'HTTP_ACCEPT' => 'image/webp,*/*'}).headers['Content-Type']
    assert_equal 'image/webp', server.get("/transparent", {'HTTP_ACCEPT' => 'image/webp,*/*'}).headers['Content-Type']

    # Firefox 47 to 63
    assert_equal 'image/jpeg', server.get("/opaque", {'HTTP_ACCEPT' => '*/*'}).headers['Content-Type']
    assert_equal 'image/png', server.get("/transparent", {'HTTP_ACCEPT' => '*/*'}).headers['Content-Type']

    # Firefox prior to 47
    assert_equal 'image/jpeg', server.get("/opaque", {'HTTP_ACCEPT' => 'image/png,image/*;q=0.8,*/*;q=0.5'}).headers['Content-Type']
    assert_equal 'image/png', server.get("/transparent", {'HTTP_ACCEPT' => 'image/png,image/*;q=0.8,*/*;q=0.5'}).headers['Content-Type']

    # Safari (since Mac OS Big Sur)
    assert_equal 'image/webp', server.get("/opaque", {'HTTP_ACCEPT' => 'image/webp,image/png,image/svg+xml,image/*;q=0.8,video/*;q=0.8,*/*;q=0.5'}).headers['Content-Type']
    assert_equal 'image/webp', server.get("/transparent", {'HTTP_ACCEPT' => 'image/webp,image/png,image/svg+xml,image/*;q=0.8,video/*;q=0.8,*/*;q=0.5'}).headers['Content-Type']

    # Safari (before Mac OS Big Sur)
    assert_equal 'image/jpeg', server.get("/opaque", {'HTTP_ACCEPT' => 'image/png,image/svg+xml,image/*;q=0.8,video/*;q=0.8,*/*;q=0.5'}).headers['Content-Type']
    assert_equal 'image/png', server.get("/transparent", {'HTTP_ACCEPT' => 'image/png,image/svg+xml,image/*;q=0.8,video/*;q=0.8,*/*;q=0.5'}).headers['Content-Type']

    # Chrome
    assert_equal 'image/avif', server.get("/opaque", {'HTTP_ACCEPT' => 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8'}).headers['Content-Type']
    assert_equal 'image/avif', server.get("/transparent", {'HTTP_ACCEPT' => 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8'}).headers['Content-Type']
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
    assert_includes key_for_version(key_for_backend(key_for_version({
      '>= 1.19.0' => {
        im: {
          '>= 7.1.1-21' => '7d5daa0941b10cb47277e954a77413b2'
        },
        vips: {
          '>= 8.15.0' => '2f4645b128d93f5d9304b79baabb9fdd'
        }
      }
    }, mupdf_version))), Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S100/floorplan")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['592a7aed4be6c66f3deac77762153823', '2d0c2c8966dc484c540141f57ae73cae'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S50x50/floorplan")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['4bd78a3a3f7be88b2272b2697e10183b', '9863144037ac5cccca31b0d22304bf7b'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/Sx50/flyer")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['c7bb8896007fdc48fcb683a5533e5712', 'ff8552e8b6990d9b293c2c2c88bfa116'], Digest::MD5.hexdigest(response.body)
  end
  
  test 'a Video' do
    server = create_server
    
    response = server.get("/video")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['dd0af2d65277b93f7c3de4007be21081', '76311e89661fc5d21828084271c08455'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S100/video")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['549a9a3fff71f7ae5c135142a2885166', '351a240af0ec0db5758d5120abc73984'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S50x50/video")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['f103fb67f500511bd29ec10c5205b40f', '87c98e63d160c2d15ff5aeec1ed866b7'], Digest::MD5.hexdigest(response.body)
    
    response = server.get("/Sx50/video")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_includes ['d462eac44ca95715b288c4e501dc1f7d', '2b00b06f58ede4e365e3f7e33e65df99'], Digest::MD5.hexdigest(response.body)
  end
end