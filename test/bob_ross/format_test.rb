# frozen_string_literal: true

require 'test_helper'

class BobRossFormatTest < Minitest::Test
  
  ALLOWED_FIELDS_IN_STRIPPED_IMAGE = %w(
    bands
    coding
    width
    height
    xoffset
    xres
    yoffset
    yoffset
    yres
    resolution-unit
    bits-per-sample
    
    filename
    format
    interpretation
    vips-loader
    
    heif-bitdepth
    heif-compression
    heif-primary 
    n-pages
    
    jpeg-multiscan
    jpeg-chroma-subsample
  )

  # ------- JPEG test ----------------------------------------------------------
  test 'saves a jpg' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    output = image.transform({}, {format: 'image/jpeg'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end

    assert_equal 'jpegload', output.get("vips-loader")
  end
  
  test 'saves a jpeg with Quality' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    image.transform({}, {quality: 0, format: 'image/jpeg'}) do |low_q_output|
      image.transform({}, {quality: 100, format: 'image/jpeg'}) do |high_q_output|
        assert low_q_output.size < high_q_output.size
      end
    end
  end

  test 'saves a jpeg stripping the exif/metadata' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = image.transform({}, {strip: true, format: 'image/jpeg'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end

    assert (output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).empty?, "Unexpected field(s) in image: #{(output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).inspect}"
  end

  test 'saves a jpeg as progressive' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = image.transform({}, {interlace: true, format: 'image/jpeg'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end

    assert_equal 1, output.get('jpeg-multiscan')
  end
  
  # ------- JPEG 2000 test -----------------------------------------------------
  test 'saves a jp2', requires: 'image/jp2' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    output = image.transform({}, {format: 'image/jp2'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end
    
    assert_equal 'jp2kload', output.get("vips-loader")
  end
  
  test 'saves a jp2 with Quality', requires: 'image/jp2' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    image.transform({}, {quality: 0, format: 'image/jp2'}) do |low_q_output|
      image.transform({}, {quality: 100, format: 'image/jp2'}) do |high_q_output|
        assert low_q_output.size < high_q_output.size
      end
    end
  end

  test 'saves a jp2 stripping the exif/metadata', requires: 'image/jp2' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = image.transform({}, {strip: true, format: 'image/jp2'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end
    
    assert (output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).empty?, "Unexpected field(s) in image: #{(output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).inspect}"
  end

  # I think JP2 is always progressive?

  # ------- Webp test ----------------------------------------------------------
  test 'saves a webp', requires: 'image/webp' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    output = image.transform({}, {format: 'image/webp'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end

    assert_equal 'webpload', output.get("vips-loader")
  end
  
  test 'saves a webp with Quality', requires: 'image/webp' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    image.transform({}, {quality: 0, format: 'image/webp'}) do |low_q_output|
      image.transform({}, {quality: 100, format: 'image/webp'}) do |high_q_output|
        assert low_q_output.size < high_q_output.size
      end
    end
  end

  test 'saves a webp stripping the exif/metadata', requires: 'image/webp' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = image.transform({}, {strip: true, format: 'image/webp'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end

    assert (output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).empty?, "Unexpected field(s) in image: #{(output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).inspect}"
  end

  # Webp does not support progressive images

  # ------- PNG test ----------------------------------------------------------
  test 'saves a png' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    output = image.transform({}, {format: 'image/png'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end
    
    assert_equal 'pngload', output.get("vips-loader")
  end

  # PNG are lossless so no Quality levels
  
  test 'saves a png stripping the exif/metadata' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = image.transform({}, {strip: true, format: 'image/png'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end

    assert (output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).empty?, "Unexpected field(s) in image: #{(output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).inspect}"
  end

  test 'saves a png as progressive' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = image.transform({}, {interlace: true, format: 'image/png'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end
    
    assert_equal 1, output.get('interlaced')
  end

  # ------- HEIF test ----------------------------------------------------------
  test 'saves a heif', requires: 'image/heif' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    output = image.transform({}, {format: 'image/heif'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end
    
    assert_equal 'heifload', output.get("vips-loader")
  end
  
  test 'saves a heif with Quality', requires: 'image/heif' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    image.transform({}, {quality: 0, format: 'image/heif'}) do |low_q_output|
      image.transform({}, {quality: 100, format: 'image/heif'}) do |high_q_output|
        assert low_q_output.size < high_q_output.size
      end
    end
  end

  test 'saves a heif stripping the exif/metadata', requires: 'image/heif' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = image.transform({}, {strip: true, format: 'image/heif'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end
    
    assert (output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).empty?, "Unexpected field(s) in image: #{(output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).inspect}"
  end

  # HEIF does not support progressive images

  # ------- AVIF test ----------------------------------------------------------
  test 'saves a avif', requires: 'image/avif' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    output = image.transform({}, {format: 'image/avif'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end
    
    assert_equal 'heifload', output.get("vips-loader")
  end
  
  test 'saves a avif with Quality', requires: 'image/avif' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    image.transform({}, {quality: 0, format: 'image/avif'}) do |low_q_output|
      image.transform({}, {quality: 100, format: 'image/avif'}) do |high_q_output|
        assert low_q_output.size < high_q_output.size
      end
    end
  end

  test 'saves a avif stripping the exif/metadata', requires: 'image/avif' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = image.transform({}, {strip: true, format: 'image/avif'}) do |transformed|
      ::Vips::Image.new_from_file(transformed.path)
    end
    
    assert (output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).empty?, "Unexpected field(s) in image: #{(output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).inspect}"
  end

  # AVIF does not support progressive images

end