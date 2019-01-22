require 'securerandom'
require 'test_helper'

class BobRoss::PaletteTest < Minitest::Test

  def setup
    @cache_dir = Dir.mktmpdir
  end
  
  def teardown
    FileUtils.remove_entry @cache_dir
  end
  
  test 'set/get' do
    palette = BobRoss::Palette.new(@cache_dir, File.join(@cache_dir, 'bobross.cache'))
    key = '912ec803b2ce49e4a541068d495ab570'
    transform = 'S100x100'

    assert palette.get(key, transform).to_a.empty?
    assert_equal 0, palette.size
    
    time = Time.now
    travel_to(time) do
      palette.set(key, true, transform, 'image/png', fixture('opaque'))
    end
    
    assert File.exists?(File.join(@cache_dir, '912e/c803/b2ce/49e4a541068d495ab570/S100x100/png'))
    assert_equal File.size(fixture('opaque')), palette.size
    assert_equal [[key, 1, transform, File.size(fixture('opaque')), 'image/png', time.to_i]], palette.get(key, transform)
  end
  
  test 'size of cache doesnt go above mas size' do
    size = File.size(fixture('opaque'))
    palette = BobRoss::Palette.new(@cache_dir, File.join(@cache_dir, 'bobross.cache'), size: size * 5)
    keys = Array.new(5) { SecureRandom.hex(32) }
    transform = 'S100x100'
    
    time = Time.now
    keys.each do |key|
      travel_to(time) do
        palette.set(key, true, transform, 'image/png', fixture('opaque'))
      end
      time += 1
    end

    assert_equal size * 5, palette.size

    keys << SecureRandom.hex(32)
    palette.set(keys.last, true, transform, 'image/png', fixture('opaque'))
    
    assert_equal size * 5, palette.size
  end

end