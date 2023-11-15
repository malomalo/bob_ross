# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require 'byebug'
require 'bob_ross'
require 'bob_ross/server'
require 'bob_ross/cache'
require 'bob_ross/plugins/pdf'
require 'bob_ross/plugins/video'
require "minitest/autorun"
require 'minitest/unit'
require 'minitest/reporters'
require 'mocha'
require 'mocha/minitest'
# require 'rack/test'
require 'active_support/testing/time_helpers'
require 'standard_storage'
require 'standard_storage/filesystem'
require "concurrent"
require 'ruby-vips'



BobRoss.configure(backend: ENV["BOBROSS_BACKEND"]) if ENV["BOBROSS_BACKEND"]

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
BobRoss.logger = Logger.new(IO::NULL, level: :fatal)

# File 'lib/active_support/testing/declarative.rb', somewhere in rails....
class Minitest::Test
  
 include ActiveSupport::Testing::TimeHelpers
  
  # File 'lib/active_support/testing/declarative.rb'
  def self.test(name, requires: nil, &block)
    test_name = "test_#{name.gsub(/\s+/, '_')}".to_sym
    defined = method_defined? test_name
    raise "#{test_name} is already defined in #{self}" if defined
    if block_given?
      define_method(test_name) do
        if requires && !BobRoss.backend.supports?(*requires)
          skip "Format #{requires.inspect} not supported"
        else
          instance_eval(&block)
        end
      end
    else
      define_method(test_name) do
        skip "No implementation provided for #{name}"
      end
    end
  end
  
  def wait_until
    while !yield
      sleep 0.1
    end
  end
  
  def debug
    $debug = true
    yield
  ensure
    $debug = false
  end

  def color_to_rgba(value)
    "##{value.map {|i| i.to_i.to_s(16) }.join('')}"
  end
  
  def assert_color(exp, actual)
    actual = color_to_rgba(actual)
    if exp.length < actual.length
      exp += 'ff'
    end
    assert_equal(exp, actual)
  end
  
  def assert_geometry(geom, image)
    image = ::Vips::Image.new_from_file(image.path)
    
    assert_equal geom, "#{image.width}x#{image.height}"
  end
  
  # exp is the signature or [IM sig, libvips sig]
  def assert_signature(exp, image)
    if exp.is_a?(Array)
      if BobRoss.backend.name == 'BobRoss::ImageMagickBackend'
        exp = exp.first
      else
        exp = exp.last
      end
    end

    signature = `identify -verbose '#{image.path}'`.match(/signature: (\w+)/)[1]
    assert_equal(exp, signature)
  end
  
  def assert_transform(input, transform, tests)
    output = input.transform(transform)

    bnd = BobRoss.backend.name == 'BobRoss::ImageMagickBackend' ? 'imagemagick' : 'libvips'
    line = caller.find { |l| l.start_with?(File.dirname(__FILE__)) }.delete_prefix(File.dirname(__FILE__)).split(':')
    # `cp '#{output.path}' ~/test/#{File.basename(line.first).split('.').first}.#{line[1]}.#{bnd}#{File.extname(output.path)}`

    tests.each do |k, v|
      send("assert_#{k}", v, output)
    end
  end
  
  def assert_file(path)
    assert File.exist?(path), "Expected file #{path.inspect} to exist, but does not"
  end
  
  def assert_no_file(path)
    assert !File.exist?(path), "Expected file #{path.inspect} to not exist, but does"
  end
  
  def assert_dir(path)
    assert Dir.exist?(path), "Expected file #{path.inspect} to exist, but does not"
  end
  
  def assert_no_dir(path)
    assert !Dir.exist?(path), "Expected file #{path.inspect} to not exist, but does"
  end
  
  def fixture(path)
    File.open(File.expand_path(File.join('../fixtures', path), __FILE__))
  end
  
  # test/unit backwards compatibility methods
  alias :assert_raise :assert_raises
  alias :assert_not_empty :refute_empty
  alias :assert_not_equal :refute_equal
  alias :assert_not_in_delta :refute_in_delta
  alias :assert_not_in_epsilon :refute_in_epsilon
  alias :assert_not_includes :refute_includes
  alias :assert_not_instance_of :refute_instance_of
  alias :assert_not_kind_of :refute_kind_of
  alias :assert_no_match :refute_match
  alias :assert_not_nil :refute_nil
  alias :assert_not_operator :refute_operator
  alias :assert_not_predicate :refute_predicate
  alias :assert_not_respond_to :refute_respond_to
  alias :assert_not_same :refute_same
  
end

Dir.glob(File.expand_path('../models/**/*.rb', __FILE__), &method(:require))