require 'securerandom'
require 'test_helper'

class BobRoss::CacheTest < Minitest::Test

  def setup
    @cache_dir = Dir.mktmpdir
  end
  
  def teardown
    FileUtils.remove_entry @cache_dir
  end
  
  test 'cache size as a percentage of the disk' do
    dev_size = if File.exists?('/proc/mounts')
      mount_points = File.read('/proc/mounts').each_line.map{ |l| l.split(/\s+/)[0..1] }
      dev = mount_points.select{ |a| @cache_dir.start_with?(a[1]) }.sort_by {|a| a[1].length }.last[0]
      Terrapin::CommandLine.new("lsblk", "-rbno SIZE :dev").run(dev: dev).to_i
    else
      mounts = Terrapin::CommandLine.new("df", "-lk").run.split("\n")[1..-1].map{ |l| l.split(/\s+/) }.map{|l| [l[0], l[1], l[8]] }
      dev = mounts.select{ |a| @cache_dir.start_with?(a[2]) }.sort_by {|a| a[2].length }.last
      dev[1].to_i * 1024
    end
    
    cache = BobRoss::Cache.new(@cache_dir, File.join(@cache_dir, 'bobross.cache'), size: '75%')
    assert_equal( (dev_size*0.75).round, cache.max_size )
  end
  
  test 'set/get' do
    cache = BobRoss::Cache.new(@cache_dir, File.join(@cache_dir, 'bobross.cache'))
    key = '912ec803b2ce49e4a541068d495ab570'
    transform = 'S100x100'

    assert cache.get(key, transform).to_a.empty?
    assert_equal 0, cache.size
    
    time = Time.now
    travel_to(time) do
      cache.set(key, true, transform, 'image/png', fixture('opaque'))
    end
    
    assert File.exists?(File.join(@cache_dir, '912e/c803/b2ce/49e4a541068d495ab570/S100x100/png'))
    assert_equal File.size(fixture('opaque')), cache.size
    assert_equal [[key, 1, transform, File.size(fixture('opaque')), 'image/png', time.to_i]], cache.get(key, transform)
  end
  
  test 'purge!' do
    cache = BobRoss::Cache.new(@cache_dir, File.join(@cache_dir, 'bobross.cache'), size: 1)
    key = '912ec803b2ce49e4a541068d495ab570'
    transform = 'S100x100'

    cache.set(key, true, transform, 'image/png', fixture('opaque'))
    assert_file File.join(@cache_dir, '912e/c803/b2ce/49e4a541068d495ab570/S100x100/png')
    assert_dir  File.join(@cache_dir, '912e')
    
    cache.purge!
    assert_equal 0, cache.size
    assert_no_file File.join(@cache_dir, '912e/c803/b2ce/49e4a541068d495ab570/S100x100/png')
    assert_no_dir  File.join(@cache_dir, '912e')
  end
  
  test 'del' do
    cache = BobRoss::Cache.new(@cache_dir, File.join(@cache_dir, 'bobross.cache'), size: 1)
    key = '912ec803b2ce49e4a541068d495ab570'
    transform = 'S100x100'

    cache.set(key, true, transform, 'image/png', fixture('opaque'))
    assert_file File.join(@cache_dir, '912e/c803/b2ce/49e4a541068d495ab570/S100x100/png')
    assert_dir  File.join(@cache_dir, '912e')
    
    cache.del('912ec803b2ce49e4a541068d495ab570')
    assert_equal 0, cache.size
    assert_no_file File.join(@cache_dir, '912e/c803/b2ce/49e4a541068d495ab570/S100x100/png')
    assert_no_dir  File.join(@cache_dir, '912e')
  end
  
  test 'size of cache doesnt go above max size' do
    size = File.size(fixture('opaque'))
    cache = BobRoss::Cache.new(@cache_dir, File.join(@cache_dir, 'bobross.cache'), size: size * 5)
    keys = Array.new(5) { SecureRandom.hex(32) }
    transform = 'S100x100'
    
    time = Time.now
    keys.each do |key|
      travel_to(time) do
        cache.set(key, true, transform, 'image/png', fixture('opaque'))
      end
      time += 1
    end

    assert_equal size * 5, cache.size

    keys << SecureRandom.hex(32)
    cache.set(keys.last, true, transform, 'image/png', fixture('opaque'))
    
    assert_equal size * 5, cache.size
  end

end