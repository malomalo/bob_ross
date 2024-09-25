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
  
  test 'a malformed crop transformation' do
    server = create_server
    
    response = server.get('/C___S100x100/opaque')
    assert_equal 422, response.status
    assert_equal 'Invalid geometry "___"', response.body
  end
  
  test 'a PDF' do
    server = create_server
    
    response = server.get("/flyer")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_equal value_for_versions(key_for_backend({
      im: {
        ['>= 7.1.1-21', ['>= 1.19.0', '< 1.22.2']] => 'c0e5d6b674ed162bfdd212cffad42585',
        ['>= 7.1.1-21', ['>= 1.22.2']] => '7d5daa0941b10cb47277e954a77413b2'
      }, vips: {
        ['>= 8.15.0', ['>= 1.19.0', '< 1.22.2']] => 'c0bd56a48d4c81423ae926988d21c55f',
        ['>= 8.15.0', ['>= 1.22.2']] => '2f4645b128d93f5d9304b79baabb9fdd'
      }}), BobRoss.backend.version, mupdf_version
    ), Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S100/floorplan")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_equal value_for_versions(key_for_backend({
      im: {
        ['>= 7.1.1-21', ['>= 1.19.0', '< 1.22.2']] => 'bab2943711de8adcf01a711983c52b15',
        ['>= 7.1.1-21', ['>= 1.22.2']] => '592a7aed4be6c66f3deac77762153823'
      }, vips: {
        ['>= 8.15.0', ['>= 1.19.0', '< 1.22.2']] => 'fb65fd6089b9b01aa71a95f053cc09bb',
        ['>= 8.15.0', ['>= 1.22.2']] => '2d0c2c8966dc484c540141f57ae73cae'
      }}), BobRoss.backend.version, mupdf_version
    ), Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S50x50/floorplan")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_equal value_for_versions(key_for_backend({
      im: {
        ['>= 7.1.1-21', ['>= 1.19.0', '< 1.22.2']] => 'f6df84e2708d0add72f1e3d3e28098cb',
        ['>= 7.1.1-21', ['>= 1.22.2']] => '4bd78a3a3f7be88b2272b2697e10183b'
      }, vips: {
        ['>= 8.15.0', ['>= 1.19.0', '< 1.22.2']] => 'e42bb91cf34a3cce419ffec9fbefec0e',
        ['>= 8.15.0', ['>= 1.22.2']] => '9863144037ac5cccca31b0d22304bf7b'
      }}), BobRoss.backend.version, mupdf_version
    ), Digest::MD5.hexdigest(response.body)
    
    response = server.get("/Sx50/flyer")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_equal value_for_versions(key_for_backend({
      im: {
        ['>= 7.1.1-21', ['>= 1.19.0', '< 1.22.2']] => 'deafd01854b9ed9aaacb6b486d30f290',
        ['>= 7.1.1-21', ['>= 1.22.2']] => 'c7bb8896007fdc48fcb683a5533e5712'
      }, vips: {
        ['>= 8.15.0', ['>= 1.19.0', '< 1.22.2']] => '86b2fbe3f875ca59b77d9d1abaff0e2e',
        ['>= 8.15.0', ['>= 1.22.2']] => 'ff8552e8b6990d9b293c2c2c88bfa116'
      }}), BobRoss.backend.version, mupdf_version
    ), Digest::MD5.hexdigest(response.body)
  end
  
  test 'a Video' do
    server = create_server
    
    response = server.get("/video")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_equal value_for_versions(key_for_backend({
      im: {
        ['>= 7.1.1-21', ['>= 4.4.2-0', '< 6.0']] => 'f0b9194eafb984d4d4273c33570eb91b',
        ['>= 7.1.1-21', ['>= 6.0']] => 'dd0af2d65277b93f7c3de4007be21081'
      }, vips: {
        ['>= 8.15.0', ['>= 4.4.2-0', '< 6.0']] => '85196b91ab4e189da1eef3fda9d7fce8',
        ['>= 8.15.0', ['>= 6.0']] => '76311e89661fc5d21828084271c08455'
      }}), BobRoss.backend.version, ffmpeg_version
    ), Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S100/video")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_equal value_for_versions(key_for_backend({
      im: {
        ['>= 7.1.1-21', ['>= 4.4.2-0', '< 6.0']] => '69f8bd89d373f45f6ee92cd8db8fa096',
        ['>= 7.1.1-21', ['>= 6.0']] => '549a9a3fff71f7ae5c135142a2885166'
      }, vips: {
        ['>= 8.15.0', ['>= 4.4.2-0', '< 6.0']] => 'df8501dba59a7f5d34f26cf932b857e7',
        ['>= 8.15.0', ['>= 6.0']] => '351a240af0ec0db5758d5120abc73984'
      }}), BobRoss.backend.version, ffmpeg_version
    ), Digest::MD5.hexdigest(response.body)
    
    response = server.get("/S50x50/video")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_equal value_for_versions(key_for_backend({
      im: {
        ['>= 7.1.1-21', ['>= 4.4.2-0', '< 6.0']] => '9418f242fbbca265063ccef0b8313d71',
        ['>= 7.1.1-21', ['>= 6.0']] => 'f103fb67f500511bd29ec10c5205b40f'
      }, vips: {
        ['>= 8.15.0', ['>= 4.4.2-0', '< 6.0']] => '8db0afaf7f747d2d6884e115e3f018a5',
        ['>= 8.15.0', ['>= 6.0']] => '87c98e63d160c2d15ff5aeec1ed866b7'
      }}), BobRoss.backend.version, ffmpeg_version
    ), Digest::MD5.hexdigest(response.body)
    
    response = server.get("/Sx50/video")
    assert_equal 'image/jpeg', response.headers['Content-Type']
    assert_equal value_for_versions(key_for_backend({
      im: {
        ['>= 7.1.1-21', ['>= 4.4.2-0', '< 6.0']] => '700f7a0e8cfb73345a0e60d66255f4c2',
        ['>= 7.1.1-21', ['>= 6.0']] => 'd462eac44ca95715b288c4e501dc1f7d'
      }, vips: {
        ['>= 8.15.0', ['>= 4.4.2-0', '< 6.0']] => '448cb17829d0adf6e0326239cb3c32d5',
        ['>= 8.15.0', ['>= 6.0']] => '2b00b06f58ede4e365e3f7e33e65df99'
      }}), BobRoss.backend.version, ffmpeg_version
    ), Digest::MD5.hexdigest(response.body)
  end
end