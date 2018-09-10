require 'test_helper'

class BobRoss::Palette::ServerClientTest < Minitest::Test

  def setup
    @cache_dir = Dir.mktmpdir
    @server = BobRoss::PaletteServer.new(@cache_dir)
    @thread = Thread.new { @server.run }
    @client = BobRoss::PaletteClient.new
  end
  
  def teardown
    @server.stop
    @thread.join
    FileUtils.remove_entry @cache_dir
  end
  
  test 'set/get/del' do
    key = '912ec803b2ce49e4a541068d495ab570'

    assert_nil @client.get(key)
    
    @client.set(key, fixture('opaque'))
    
    assert File.exists?(File.join(@cache_dir, '912e/c803/b2ce49e4a541068d495ab570'))
    assert_equal File.join(@cache_dir, '912e/c803/b2ce49e4a541068d495ab570'), @client.get(key)
    
    @client.del(key)
    assert !File.exists?(File.join(@cache_dir, '912e/c803/b2ce49e4a541068d495ab570'))
  end

end