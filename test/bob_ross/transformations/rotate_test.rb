# frozen_string_literal: true

require 'test_helper'

class BobRossTransformationsRotateTest < Minitest::Test
  
  test 'rotating an image' do
    image = BobRoss::Image.new(fixture('opaque'))

    assert_transform(image, {rotate: 0}, { geometry: '720x480' })
    assert_transform(image, {rotate: 8}, { geometry: BobRoss.backend == BobRoss::ImageMagickBackend ? '782x578' : '780x576' })
    assert_transform(image, {rotate: 45}, { geometry: BobRoss.backend == BobRoss::ImageMagickBackend ? '850x850' : '849x849' })
    assert_transform(image, {rotate: 90}, { geometry: '480x720' })
    assert_transform(image, {rotate: 135}, { geometry: BobRoss.backend == BobRoss::ImageMagickBackend ? '850x850' : '849x849' })
    assert_transform(image, {rotate: 180}, { geometry: '720x480' })
    assert_transform(image, {rotate: 225}, { geometry: BobRoss.backend == BobRoss::ImageMagickBackend ? '850x850' : '849x849' })
    assert_transform(image, {rotate: 270}, { geometry: '480x720' })
    assert_transform(image, {rotate: 315}, { geometry: BobRoss.backend == BobRoss::ImageMagickBackend ? '850x850' : '849x849' })
    assert_transform(image, {rotate: 360}, { geometry: '720x480' })
  end
end