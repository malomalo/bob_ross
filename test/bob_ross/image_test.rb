require 'test_helper'

class BobRossImageTest < Minitest::Test
  
  test 'detects when an image is opaque' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    assert_equal true, image.opaque
    assert_equal false, image.transparent
  end
  
  test 'detects when an image is transparent' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))
    assert_equal false, image.opaque
    assert_equal true, image.transparent
  end

  test 'detects an image mime type' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))
    assert_equal 'image/png', image.mime_type.to_s
  end
  
  test 'detects image geometry' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))
    assert_equal({width: 720, height: 480, x_offset: nil, y_offset: nil}, image.geometry)
  end
  
end