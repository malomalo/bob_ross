require 'test_helper'

class BobRossTest < Minitest::Test
  
  def setup
    BobRoss.defaults = {}
  end
  
  test "encode_transformations" do
    time = 1449100194
    
    assert_equal "BeeddccaaE#{time.to_s(16)}GILOP1,2,3,4S500x500^W0se", BobRoss.encode_transformations({
      optimize: true,
      interlace: true,
      resize: '500x500^',
      background: 'eeddccaa',
      expires: time,
      grayscale: true,
      lossless: true,
      padding: [1,2,3,4],
      transparent: true,
      watermark: 0
    })
  end
  
  test "defaults" do
    time = 1449100194
    BobRoss.defaults = {
      optimize: true,
      interlace: true,
      resize: '500x500^',
      background: 'eeddccaa',
      expires: time,
      grayscale: true,
      lossless: true,
      transparent: true,
      watermark: 0,
      host: 'https://example.com',
      filename: 'image',
      format: 'png',
      hmac: {
        key: 'secret',
        attributes: [:hash]
      }
    }
    
    assert_equal "https://example.com/H41482f0113cc9843f0aeaa10631936644a164059BeeddccaaE#{time.to_s(16)}GILOS500x500%5EW0se/hash/image.png", BobRoss.url('hash')
  end
  
  test "url" do
    # /hash
    assert_equal '/hash', BobRoss.path('hash')
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash', BobRoss.path('hash', hmac: {key: 'secret'})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash', BobRoss.path('hash', hmac: {key: 'secret', attributes: [:hash]})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash', BobRoss.path('hash', hmac: {key: 'secret', attributes: [:transformations, :hash]})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash', BobRoss.path('hash', hmac: {key: 'secret', attributes: [:transformations, :hash, :format]})
    
    # /hash.format
    assert_equal '/hash.jpg', BobRoss.path('hash', format: :jpg)
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash.jpg', BobRoss.path('hash', format: :jpg, hmac: {key: 'secret'})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash.jpg', BobRoss.path('hash', format: :jpg, hmac: {key: 'secret', attributes: [:hash]})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash.jpg', BobRoss.path('hash', format: :jpg, hmac: {key: 'secret', attributes: [:transformations, :hash]})
    assert_equal '/H71b41412267a864bb3eaf532db2ad7eb3214aa1f/hash.jpg', BobRoss.path('hash', format: :jpg, hmac: {key: 'secret', attributes: [:transformations, :hash, :format]})
    
    # /hash/filename
    assert_equal '/hash/my+Filename%26', BobRoss.path('hash', filename: 'my Filename&')
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26', BobRoss.path('hash', filename: 'my Filename&', hmac: {key: 'secret'})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26', BobRoss.path('hash', filename: 'my Filename&', hmac: {key: 'secret', attributes: [:hash]})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26', BobRoss.path('hash', filename: 'my Filename&', hmac: {key: 'secret', attributes: [:transformations, :hash]})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26', BobRoss.path('hash', filename: 'my Filename&', hmac: {key: 'secret', attributes: [:transformations, :hash, :format]})
    
    # /hash/filename.format
    assert_equal '/hash/my+Filename%26.png', BobRoss.path('hash', filename: 'my Filename&', format: :png)
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26.png', BobRoss.path('hash', filename: 'my Filename&', format: :png, hmac: {key: 'secret'})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26.png', BobRoss.path('hash', filename: 'my Filename&', format: :png, hmac: {key: 'secret', attributes: [:hash]})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26.png', BobRoss.path('hash', filename: 'my Filename&', format: :png, hmac: {key: 'secret', attributes: [:transformations, :hash]})
    assert_equal '/H780361d0a2c5d5204d111586d64abf835915043f/hash/my+Filename%26.png', BobRoss.path('hash', filename: 'my Filename&', format: :png, hmac: {key: 'secret', attributes: [:transformations, :hash, :format]})
    
    # /transform/hash
    assert_equal '/O/hash', BobRoss.path('hash', optimize: true)
    assert_equal '/Hc109ec7293d935546fab58a51e7b925c1bda1b73O/hash', BobRoss.path('hash', optimize: true, hmac: {key: 'secret'})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059O/hash', BobRoss.path('hash', optimize: true, hmac: {key: 'secret', attributes: [:hash]})
    assert_equal '/Hc109ec7293d935546fab58a51e7b925c1bda1b73O/hash', BobRoss.path('hash', optimize: true, hmac: {key: 'secret', attributes: [:transformations, :hash]})
    assert_equal '/Hc109ec7293d935546fab58a51e7b925c1bda1b73O/hash', BobRoss.path('hash', optimize: true, hmac: {key: 'secret', attributes: [:transformations, :hash, :format]})
    
    # /hash.format
    assert_equal '/I/hash.jpg', BobRoss.path('hash', interlace: true, format: :jpg)
    assert_equal '/Hdd37bbe6fc1c96742293425071393723e3c54e3eI/hash.jpg', BobRoss.path('hash', interlace: true, format: :jpg, hmac: {key: 'secret'})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059I/hash.jpg', BobRoss.path('hash', interlace: true, format: :jpg, hmac: {key: 'secret', attributes: [:hash]})
    assert_equal '/Hdd37bbe6fc1c96742293425071393723e3c54e3eI/hash.jpg', BobRoss.path('hash', interlace: true, format: :jpg, hmac: {key: 'secret', attributes: [:transformations, :hash]})
    assert_equal '/H6daa14c7133b00a5a5ef8f23671b97d0dd5ad149I/hash.jpg', BobRoss.path('hash', interlace: true, format: :jpg, hmac: {key: 'secret', attributes: [:transformations, :hash, :format]})
    
    # /hash/filename
    assert_equal '/S500x500/hash/my+Filename%26', BobRoss.path('hash', resize: '500x500', filename: 'my Filename&')
    assert_equal '/He9f14c0ae58cf300d6b9655889c2661c591d7b4bS500x500/hash/my+Filename%26', BobRoss.path('hash', resize: '500x500', filename: 'my Filename&', hmac: {key: 'secret'})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059S500x500/hash/my+Filename%26', BobRoss.path('hash', resize: '500x500', filename: 'my Filename&', hmac: {key: 'secret', attributes: [:hash]})
    assert_equal '/He9f14c0ae58cf300d6b9655889c2661c591d7b4bS500x500/hash/my+Filename%26', BobRoss.path('hash', resize: '500x500', filename: 'my Filename&', hmac: {key: 'secret', attributes: [:transformations, :hash]})
    assert_equal '/He9f14c0ae58cf300d6b9655889c2661c591d7b4bS500x500/hash/my+Filename%26', BobRoss.path('hash', resize: '500x500', filename: 'my Filename&', hmac: {key: 'secret', attributes: [:transformations, :hash, :format]})
    
    # /hash/filename.format
    assert_equal '/Baabbcc/hash/my+Filename%26.png', BobRoss.path('hash', background: 'aabbcc', filename: 'my Filename&', format: :png)
    assert_equal '/Hfae60e9eb00a16c19ff01aef0cadfe6709f024e6Baabbcc/hash/my+Filename%26.png', BobRoss.path('hash', background: 'aabbcc', filename: 'my Filename&', format: :png, hmac: {key: 'secret'})
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059Baabbcc/hash/my+Filename%26.png', BobRoss.path('hash', background: 'aabbcc', filename: 'my Filename&', format: :png, hmac: {key: 'secret', attributes: [:hash]})
    assert_equal '/Hfae60e9eb00a16c19ff01aef0cadfe6709f024e6Baabbcc/hash/my+Filename%26.png', BobRoss.path('hash', background: 'aabbcc', filename: 'my Filename&', format: :png, hmac: {key: 'secret', attributes: [:transformations, :hash]})
    assert_equal '/He993a4e6169a3effcfc7f2ea39ec56cc81a41591Baabbcc/hash/my+Filename%26.png', BobRoss.path('hash', background: 'aabbcc', filename: 'my Filename&', format: :png, hmac: {key: 'secret', attributes: [:transformations, :hash, :format]})
  end
  
end