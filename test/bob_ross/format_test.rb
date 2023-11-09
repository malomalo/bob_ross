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

  # JPEG
  # PNG
  # WebP
  # HEIF
  # JXR
  
  # ------- JPEG test ----------------------------------------------------------
  test 'saves a jpg' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    output = ::Vips::Image.new_from_file(image.transform({}, {format: 'image/jpeg'}).path)
    
    assert_equal 'jpegload', output.get("vips-loader")
  end
  
  test 'saves a jpeg with Quality' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    low_q_output = image.transform({}, {quality: 1, format: 'image/jpeg'})
    high_q_output = image.transform({}, {quality: 100, format: 'image/jpeg'})
    
    assert low_q_output.size < high_q_output.size
  end

  test 'saves a jpeg stripping the exif/metadata' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = ::Vips::Image.new_from_file(image.transform({}, {strip: true, format: 'image/jpeg'}).path)

    assert (output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).empty?
  end

  test 'saves a jpeg as progressive' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = ::Vips::Image.new_from_file(image.transform({}, {interlace: true, format: 'image/jpeg'}).path)

    assert_equal 1, output.get('jpeg-multiscan')
  end

  # ------- Webp test ----------------------------------------------------------
  test 'saves a webp' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    output = ::Vips::Image.new_from_file(image.transform({}, {format: 'image/webp'}).path)
    
    assert_equal 'webpload', output.get("vips-loader")
  end
  
  test 'saves a webp with Quality' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    low_q_output = image.transform({}, {quality: 1, format: 'image/webp'})
    high_q_output = image.transform({}, {quality: 100, format: 'image/webp'})
    
    assert low_q_output.size < high_q_output.size
  end

  test 'saves a webp stripping the exif/metadata' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = ::Vips::Image.new_from_file(image.transform({}, {strip: true, format: 'image/webp'}).path)

    assert (output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).empty?
  end

  # Webp does not support progressive images

  # ------- PNG test ----------------------------------------------------------
  test 'saves a png' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    output = ::Vips::Image.new_from_file(image.transform({}, {format: 'image/png'}).path)
    
    assert_equal 'pngload', output.get("vips-loader")
  end

  # PNG are lossless so no Quality levels
  
  test 'saves a png stripping the exif/metadata' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = ::Vips::Image.new_from_file(image.transform({}, {strip: true, format: 'image/png'}).path)

    assert (output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).empty?
  end

  test 'saves a png as progressive' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = ::Vips::Image.new_from_file(image.transform({}, {interlace: true, format: 'image/png'}).path)

    assert_equal 1, output.get('interlaced')
  end

  # ------- HEIF test ----------------------------------------------------------
  test 'saves a heif' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    output = ::Vips::Image.new_from_file(image.transform({}, {format: 'image/heif'}).path)
    
    assert_equal 'heifload', output.get("vips-loader")
  end
  
  test 'saves a heif with Quality' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    low_q_output = image.transform({}, {quality: 1, format: 'image/heif'})
    high_q_output = image.transform({}, {quality: 100, format: 'image/heif'})
    
    assert low_q_output.size < high_q_output.size
  end

  test 'saves a heif stripping the exif/metadata' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/image_with_exif_data.jpg', __FILE__)))
    output = ::Vips::Image.new_from_file(image.transform({}, {strip: true, format: 'image/heif'}).path)
    
    assert (output.get_fields - ALLOWED_FIELDS_IN_STRIPPED_IMAGE).empty?
  end

  # HEIF does not support progressive images

end