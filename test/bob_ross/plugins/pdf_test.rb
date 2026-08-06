# frozen_string_literal: true

require 'test_helper'

class PDFPluginTest < Minitest::Test

  test 'extract_transformations' do
    # No transformations
    transformations = BobRoss::PDFPlugin.extract_transformations('')
    assert_equal [], transformations

    # No transformations for plugin
    transformation_string = String.new('R')
    transformations = BobRoss::PDFPlugin.extract_transformations(transformation_string)
    assert_equal [], transformations
    assert_equal 'R', transformation_string

    # Just transformations for plugin
    transformation_string = String.new('R1')
    transformations = BobRoss::PDFPlugin.extract_transformations(transformation_string)
    assert_equal [[:page, '1']], transformations
    assert_equal '', transformation_string

    # transformations for both plugin and BobRoss
    transformation_string = String.new('R10G')
    transformations = BobRoss::PDFPlugin.extract_transformations(transformation_string)
    assert_equal [[:page, '10']], transformations
    assert_equal 'G', transformation_string

    # malformed options are skipped
    transformation_string = String.new('R@G')
    transformations = BobRoss::PDFPlugin.extract_transformations(transformation_string)
    assert_equal [], transformations
    assert_equal 'R@G', transformation_string
  end

  test 'creates a thumbnail for the pdf with pdf dimensions' do
    BobRoss::PDFPlugin.transform(fixture('pdfs/sample.pdf')) do |image|
      assert_geometry('612x792', image)
      assert_signature(
        key_for_version({
          ['>= 1.19.0', '< 1.22.2'] => '169487ef32a2f4354a628160d508c2c508fdf47005ca3b91f5f1537b3efcf68c',
          '>= 1.22.2' => 'f2c56e4f41e4cea5137b2aaa6e949f50ca3cd17b9803b221dd49a1ec8891aa5b',
        }, mupdf_version),
        image
      )
    end
  end

  test 'creates a thumbnail for the pdf with pdf dimensions of requested page' do
    BobRoss::PDFPlugin.transform(fixture('pdfs/sample.pdf'), [[:page, 2]]) do |image|
      assert_geometry('612x792', image)
      assert_signature(
        key_for_version({
          ['>= 1.19.0', '< 1.22.2'] => 'f82c26383f5213193151a4e647192c123f7c24228252228d5098120e8b2895fa',
          '>= 1.22.2' => 'b6c1ff99cefbe60f59f681fc7350a83b7a9734def84888472c0616b474cf9bca',
        }, mupdf_version),
        image
      )
    end
  end
  
  test 'creates a thumbnail for the pdf with pdf dimensions of upcoming resolution requested in bobross' do
    BobRoss::PDFPlugin.transform(fixture('pdfs/sample.pdf'), [], [[:resize, '500x500']]) do |image|
      assert_geometry('387x500', image)
      assert_signature(
        key_for_version({
          ['>= 1.19.0', '< 1.22.2'] => '9e74391f349859ea0596e0f14380a69014f18f0c727749971bf4ddb2060df678',
          '>= 1.22.2' => '9571636ec1e7e74a3d5d2398258ab54f308aef79bca60451b3e4dabc9d7989c7',
        }, mupdf_version),
        image
      )
    end
  end

end