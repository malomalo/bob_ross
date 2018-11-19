# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require 'bob_ross'
require 'bob_ross/server'
require 'bob_ross/palette'
require "minitest/autorun"
require 'minitest/unit'
require 'minitest/reporters'
require 'mocha'
require 'mocha/test_unit'
# require 'rack/test'
require 'active_support/testing/time_helpers'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
BobRoss.logger = Logger.new(IO::NULL, level: :fatal)

# File 'lib/active_support/testing/declarative.rb', somewhere in rails....
class Minitest::Test
  
 include ActiveSupport::Testing::TimeHelpers
  
  # File 'lib/active_support/testing/declarative.rb'
  def self.test(name, &block)
    test_name = "test_#{name.gsub(/\s+/, '_')}".to_sym
    defined = method_defined? test_name
    raise "#{test_name} is already defined in #{self}" if defined
    if block_given?
      define_method(test_name, &block)
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

  def fixture(path)
    File.expand_path(File.join('../fixtures', path), __FILE__)
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