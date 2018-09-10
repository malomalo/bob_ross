require 'securerandom'
require 'test_helper'

class BobRoss::PaletteTest < Minitest::Test

  def setup
    @cache_dir = Dir.mktmpdir
  end
  
  def teardown
    FileUtils.remove_entry @cache_dir
  end
  
  test 'set/get/del' do
    palette = BobRoss::Palette.new(@cache_dir)
    key = '912ec803b2ce49e4a541068d495ab570'

    assert_nil palette.get(key)
    
    palette.set(key, fixture('opaque'))
    
    assert File.exists?(File.join(@cache_dir, '912e/c803/b2ce49e4a541068d495ab570'))
    assert_equal File.size(fixture('opaque')), palette.bytesize
    assert_equal File.join(@cache_dir, '912e/c803/b2ce49e4a541068d495ab570'), palette.get(key)
    
    palette.del(key)
    assert !File.exists?(File.join(@cache_dir, '912e/c803/b2ce49e4a541068d495ab570'))
    assert_equal 0, palette.bytesize
  end
  
  test 'indexes items from disk' do
    t1 = Time.now - 20
    t2 = t1 + 5
    t3 = t1 + 10
    
    FileUtils.mkdir_p(File.join(@cache_dir, '912e/c803'))
    FileUtils.cp(fixture('opaque'), File.join(@cache_dir, '912e/c803/b2ce49e4a541068d495ab570'))
    File.utime(t2, t1, File.join(@cache_dir, '912e/c803/b2ce49e4a541068d495ab570'))
    
    FileUtils.cp(fixture('transparent'), File.join(@cache_dir, '912e/c803/b2ce49e4a541068d495ab571'))
    File.utime(t3, t1, File.join(@cache_dir, '912e/c803/b2ce49e4a541068d495ab571'))
    
    palette = BobRoss::Palette.new(@cache_dir)
    wait_until { !palette.indexing }
    
    assert_equal File.size(fixture('opaque')) + File.size(fixture('transparent')), palette.bytesize
    assert_equal ['912ec803b2ce49e4a541068d495ab570', '912ec803b2ce49e4a541068d495ab571'], palette.instance_variable_get(:@index).keys
    assert_equal [t2, t3].map(&:to_i), palette.instance_variable_get(:@index).values.map(&:timestamp).map(&:to_i)
  end
  
  test 'get updates the timestamp' do
    palette = BobRoss::Palette.new(@cache_dir)
    key = '912ec803b2ce49e4a541068d495ab570'

    palette.set(key, fixture('opaque'))
    
    time = Time.now - 60
    travel_to time do
      palette.get(key)
    end

    assert_equal time.to_i, palette.instance_variable_get(:@index)[key].timestamp.to_i
  end
  
  test 'get while indexing' do
    palette = BobRoss::Palette.new(@cache_dir)
    wait_until { !palette.indexing }
    key = '912ec803b2ce49e4a541068d495ab570'
    
    assert_nil palette.get(key)
    palette.instance_variable_set(:@indexing, true)
    FileUtils.mkdir_p(File.join(@cache_dir, '912e/c803'))
    FileUtils.cp(fixture('opaque'), File.join(@cache_dir, '912e/c803/b2ce49e4a541068d495ab570'))
    assert_equal File.join(@cache_dir, '912e/c803/b2ce49e4a541068d495ab570'), palette.get(key)
    assert_equal File.size(fixture('opaque')), palette.bytesize
    assert_equal ['912ec803b2ce49e4a541068d495ab570'], palette.instance_variable_get(:@index).keys
  end
  
  test 'purging once cache is full' do
    size = File.size(fixture('opaque'))
    palette = BobRoss::Palette.new(@cache_dir, size * 10)
    keys = Array.new(10) { SecureRandom.hex(32) }
    
    keys.each { |key| palette.set(key, fixture('opaque')) }
    assert_equal false, palette.purging
    assert_equal size * 10, palette.bytesize
    
    keys << SecureRandom.hex(32)
    palette.set(keys.last, fixture('opaque'))
    wait_until { !palette.purging }
    assert_equal size * 9, palette.bytesize
  end

end