# frozen_string_literal: true

require 'test_helper'
require 'rack/mock'

class BobRossServerTest < Minitest::Test
  
  def create_store
    StandardStorage::Filesystem.new({
      path: File.expand_path('../../../fixtures', __FILE__)
    })
  end
  
  def create_server(configs={})
    configs[:store] ||= create_store
    Rack::MockRequest.new(BobRoss::Server.new(configs))
  end

  def setup
    @server = create_server
    response = @server.get("/opaque")
    assert_equal 'bytes', response['Accept-Ranges']
    @bytesize = response.body.bytesize
  end

  test 'A byte range' do
    response = @server.get("/opaque", "HTTP_RANGE" => "bytes=100-199")
    assert_equal 206, response.status
    assert_equal 100, response.body.bytesize
    assert_equal 'image/jpeg', response.headers['Content-Type']
  end

  test 'A byte range starting greater than filesize' do
    response = @server.get("/opaque", "HTTP_RANGE" => "bytes=#{@bytesize+1}-")
    assert_equal 416, response.status
    assert_equal "Invalid Range: \"#{@bytesize+1}-\"", response.body
    assert_equal 'text/plain', response.headers['Content-Type']
  end
    
  test 'A byte range ending greater than filesize' do
    response = @server.get("/opaque", "HTTP_RANGE" => "bytes=0-#{@bytesize+1}")
    assert_equal 416, response.status
    assert_equal "Invalid Range: \"0-#{@bytesize+1}\"", response.body
    assert_equal 'text/plain', response.headers['Content-Type']
  end
    
  test 'A byte range ending before the start of the range' do
    response = @server.get("/opaque", "HTTP_RANGE" => "bytes=100-90")
    assert_equal 416, response.status
    assert_equal "Invalid Range: \"100-90\"", response.body
    assert_equal 'text/plain', response.headers['Content-Type']
  end

  test 'Multiple byte ranges' do
    response = @server.get("/opaque", "HTTP_RANGE" => "bytes=100-199,800-899")
    assert_equal 206, response.status
    assert_equal 366, response.body.bytesize
    assert_equal 'multipart/byteranges; boundary=AaB03x', response.headers['Content-Type']
    assert_equal '366', response.headers['Content-Length']
    assert_equal "\r\n--AaB03x\r\ncontent-type: image/jpeg\r\ncontent-range: bytes 100-199/#{@bytesize}\r\n\r\n", response.body[0..75]
    assert_equal "\r\n--AaB03x\r\ncontent-type: image/jpeg\r\ncontent-range: bytes 800-899/#{@bytesize}\r\n\r\n", response.body[176..251]
    assert_equal "\r\n--AaB03x--\r\n", response.body[352..]
  end
    
  test 'Overlapping Byte Ranges' do
    response = @server.get("/opaque", "HTTP_RANGE" => "bytes=0-100,10-200")
    assert_equal 416, response.status
    assert_equal "Ranges Overlap", response.body
    assert_equal 'text/plain', response.headers['Content-Type']
  end

  test 'Suffix byte range greater than filesize' do
    response = @server.get("/opaque", "HTTP_RANGE" => "bytes=-#{@bytesize+1}")
    assert_equal 206, response.status
    assert_equal @bytesize, response.body.bytesize
    assert_equal 'image/jpeg', response.headers['Content-Type']
  end

  test 'An Invalid range header' do
    response = @server.get("/opaque", "HTTP_RANGE" => "kilobytes=0-100,10-200")
    assert_equal 416, response.status
    assert_equal "Invalid Range Units: \"kilobytes\"", response.body
    assert_equal 'text/plain', response.headers['Content-Type']
  end
  
end
