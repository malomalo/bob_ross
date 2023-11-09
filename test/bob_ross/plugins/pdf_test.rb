require 'test_helper'

class PDFPluginTest < Minitest::Test

  test 'extract_transformations' do
    # No transformations
    transformations = BobRoss::PDFPlugin.extract_transformations('')
    assert_equal [], transformations

    # No transformations for plugin
    transformation_string = 'R'
    transformations = BobRoss::PDFPlugin.extract_transformations(transformation_string)
    assert_equal [], transformations
    assert_equal 'R', transformation_string

    # Just transformations for plugin
    transformation_string = 'R1'
    transformations = BobRoss::PDFPlugin.extract_transformations(transformation_string)
    assert_equal [[:page, '1']], transformations
    assert_equal '', transformation_string

    # transformations for both plugin and BobRoss
    transformation_string = 'R10G'
    transformations = BobRoss::PDFPlugin.extract_transformations(transformation_string)
    assert_equal [[:page, '10']], transformations
    assert_equal 'G', transformation_string

    # malformed options are skipped
    transformation_string = 'R@G'
    transformations = BobRoss::PDFPlugin.extract_transformations(transformation_string)
    assert_equal [], transformations
    assert_equal 'R@G', transformation_string
  end

  test 'creates a thumbnail for the pdf with pdf dimensions' do
    image = BobRoss::PDFPlugin.transform(fixture('pdfs/sample.pdf'))

    assert_geometry('612x792', image)
    assert_signature(
      'f2c56e4f41e4cea5137b2aaa6e949f50ca3cd17b9803b221dd49a1ec8891aa5b',
      image
    )
  end

  test 'creates a thumbnail for the pdf with pdf dimensions of requested page' do
    image = BobRoss::PDFPlugin.transform(fixture('pdfs/sample.pdf'), [[:page, 2]])

    assert_geometry('612x792', image)
    assert_signature(
      'b6c1ff99cefbe60f59f681fc7350a83b7a9734def84888472c0616b474cf9bca',
      image
    )
  end
  
  test 'creates a thumbnail for the pdf with pdf dimensions of upcoming resolution requested in bobross' do
    image = BobRoss::PDFPlugin.transform(fixture('pdfs/sample.pdf'), [], [[:resize, '500x500']])

    assert_geometry('387x500', image)
    assert_signature(
      '9571636ec1e7e74a3d5d2398258ab54f308aef79bca60451b3e4dabc9d7989c7',
      image
    )
  end

end