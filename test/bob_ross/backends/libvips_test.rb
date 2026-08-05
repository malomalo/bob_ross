# frozen_string_literal: true

require 'test_helper'

class BobRossLibVipsBackendTest < Minitest::Test

  def setup
    skip "libvips backend only" unless BobRoss.backend.key == :vips
  end

  test 'untrusted loaders are blocked by default' do
    Tempfile.create(['crafted', '.mat'], binmode: true) do |file|
      header = "MATLAB 5.0 MAT-file".ljust(116, " ") + " " * 8 + "\x00\x01IM"
      file.write(header + "\x00" * 256)
      file.flush

      error = assert_raises(Vips::Error) { BobRoss.backend.vips_load(file.path) }
      assert_match(/not a known file format/, error.message)
    end
  end

  test 'configure applies allow as loader exemptions through the backend' do
    BobRoss::LibVipsBackend.expects(:safe!).with(allowed: ['VipsForeignLoadJp2k']).once
    BobRoss.configure(backend: 'libvips', allow: ['VipsForeignLoadJp2k'], logger: BobRoss.logger)
  ensure
    BobRoss::LibVipsBackend.unstub(:safe!)
    BobRoss.configure(backend: 'libvips', logger: BobRoss.logger)
  end

  test 'safe: false does not enable the block on configure' do
    BobRoss::LibVipsBackend.expects(:safe!).never
    BobRoss.configure(backend: 'libvips', safe: false, logger: BobRoss.logger)
  ensure
    # Restore the suite's configuration (safe! is idempotent, so the block
    # and its exemptions are unaffected)
    BobRoss::LibVipsBackend.unstub(:safe!)
    BobRoss.configure(backend: 'libvips', allow: ['VipsForeignLoadSvg', 'VipsForeignLoadJp2k'], logger: BobRoss.logger)
  end

  test 'server does not secure the backend when BobRoss is already configured' do
    BobRoss::LibVipsBackend.expects(:safe!).never
    BobRoss::Server.new
  end

  test 'server secures the backend when BobRoss was never configured (standalone)' do
    BobRoss.stubs(:configured?).returns(false)
    BobRoss::LibVipsBackend.expects(:safe!).with(allowed: ['VipsForeignLoadSvg']).once
    BobRoss::Server.new(allow: ['VipsForeignLoadSvg'])
  end

  test 'server safe: false skips securing when BobRoss was never configured' do
    BobRoss.stubs(:configured?).returns(false)
    BobRoss::LibVipsBackend.expects(:safe!).never
    BobRoss::Server.new(safe: false)
  end

  test 'vips_load loads SVGs from a buffer so they cannot reference any resource' do
    with_loader('VipsForeignLoadSvg') do
      Dir.mktmpdir do |dir|
        secret = Vips::Image.black(4, 4).new_from_image([255, 0, 0])
        secret.write_to_file(File.join(dir, 'secret.png'))

        relative = %{<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="4" height="4"><image xlink:href="secret.png" x="0" y="0" width="4" height="4"/></svg>}
        absolute = %{<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="4" height="4"><image xlink:href="file://#{File.join(dir, 'secret.png')}" x="0" y="0" width="4" height="4"/></svg>}

        # Sanity check: librsvg resolves the sibling when rendered in place…
        File.write(File.join(dir, 'evil.svg'), relative)
        raw = Vips::Image.new_from_file(File.join(dir, 'evil.svg'))
        assert raw.getpoint(0, 0)[0] > 200, "expected the sibling file to render in place"

        # …but loaded from a buffer there is no base URI, so neither relative
        # nor absolute references resolve
        [relative, absolute].each do |svg|
          File.write(File.join(dir, 'evil.svg'), svg)
          image = BobRoss.backend.vips_load(File.join(dir, 'evil.svg'))
          assert image.getpoint(0, 0)[3] == 0.0, "expected a blank render, got #{image.getpoint(0, 0).inspect}"
        end
      end
    end
  end

  test 'SVGs with embedded data: URIs still render when loaded from a buffer' do
    with_loader('VipsForeignLoadSvg') do
      Tempfile.create(['test', '.svg']) do |file|
        red = Vips::Image.black(4, 4).new_from_image([255, 0, 0]).write_to_buffer('.png')
        file.write(%{<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="4" height="4"><image xlink:href="data:image/png;base64,#{[red].pack('m0')}" x="0" y="0" width="4" height="4"/></svg>})
        file.flush

        image = BobRoss.backend.vips_load(file.path)
        assert image.getpoint(0, 0)[0] > 200, "expected the embedded image to render"
      end
    end
  end

end
