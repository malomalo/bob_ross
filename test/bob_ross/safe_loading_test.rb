# frozen_string_literal: true

require 'test_helper'

class SafeLoadingTest < Minitest::Test

  def teardown
    BobRoss.safe_loading = true
  end

  def red?(px)
    px[0].to_i > 200 && px[1].to_i < 60 && px[2].to_i < 60
  end

  test 'safe_loading loads SVGs from a buffer so they cannot read sibling files' do
    skip 'libvips backend only' unless BobRoss.backend.key == :vips

    Dir.mktmpdir do |dir|
      # a solid-red sibling the SVG tries to embed by relative name
      ::Vips::Image.black(12, 12).new_from_image([255, 0, 0]).write_to_file(File.join(dir, 'secret.png'))
      svg_path = File.join(dir, 'evil.svg')
      File.write(svg_path, <<~SVG)
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="12" height="12">
          <image xlink:href="secret.png" x="0" y="0" width="12" height="12"/>
        </svg>
      SVG

      loader = ::Vips.vips_foreign_find_load(svg_path)
      skip 'no libvips SVG loader available' unless loader&.start_with?('VipsForeignLoadSvg')

      BobRoss.safe_loading = true
      safe = BobRoss::LibVipsBackend.vips_load_safely(svg_path).flatten(background: [255, 255, 255])
      refute red?(safe.getpoint(6, 6)), 'sibling file was read into the SVG with safe_loading on'

      BobRoss.safe_loading = false
      unsafe = BobRoss::LibVipsBackend.vips_load_safely(svg_path).flatten(background: [255, 255, 255])
      assert red?(unsafe.getpoint(6, 6)), 'expected the sibling read to occur with safe_loading off (test is not exercising the vector)'
    end
  end

end
