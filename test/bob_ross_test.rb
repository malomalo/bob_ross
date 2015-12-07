require 'test_helper'

class BobRossTest < Minitest::Test
  
  def setup
    BobRoss.hmac = {
      key: 'secret'
    }
    BobRoss.defaults = {
      
    }
  end
  
  test "encode_transformations" do
    time = 1449100194
    
    assert_equal "OPS500x500%5eBeeddccaaE#{time.to_s(16)}", BobRoss.encode_transformations({
      optimize: true,
      progressive: true,
      resize: '500x500^',
      background: 'eeddccaa',
      expires: time
    })
  end
  
  test "url" do
    # /hash
    assert_equal '/hash', BobRoss.path('hash')
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash', BobRoss.path('hash', hmac: true)
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash', BobRoss.path('hash', hmac: [:hash])
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash', BobRoss.path('hash', hmac: [:transformations, :hash])
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash', BobRoss.path('hash', hmac: [:transformations, :hash, :format])
    
    # /hash.format
    assert_equal '/hash.jpg', BobRoss.path('hash', format: :jpg)
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash.jpg', BobRoss.path('hash', format: :jpg, hmac: true)
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash.jpg', BobRoss.path('hash', format: :jpg, hmac: [:hash])
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash.jpg', BobRoss.path('hash', format: :jpg, hmac: [:transformations, :hash])
    assert_equal '/H71b41412267a864bb3eaf532db2ad7eb3214aa1f/hash.jpg', BobRoss.path('hash', format: :jpg, hmac: [:transformations, :hash, :format])
    
    # /hash/filename
    assert_equal '/hash/my+Filename%26', BobRoss.path('hash', filename: 'my Filename&')
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26', BobRoss.path('hash', filename: 'my Filename&', hmac: true)
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26', BobRoss.path('hash', filename: 'my Filename&', hmac: [:hash])
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26', BobRoss.path('hash', filename: 'my Filename&', hmac: [:transformations, :hash])
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26', BobRoss.path('hash', filename: 'my Filename&', hmac: [:transformations, :hash, :format])
    
    # /hash/filename.format
    assert_equal '/hash/my+Filename%26.png', BobRoss.path('hash', filename: 'my Filename&', format: :png)
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26.png', BobRoss.path('hash', filename: 'my Filename&', format: :png, hmac: true)
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26.png', BobRoss.path('hash', filename: 'my Filename&', format: :png, hmac: [:hash])
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059/hash/my+Filename%26.png', BobRoss.path('hash', filename: 'my Filename&', format: :png, hmac: [:transformations, :hash])
    assert_equal '/H780361d0a2c5d5204d111586d64abf835915043f/hash/my+Filename%26.png', BobRoss.path('hash', filename: 'my Filename&', format: :png, hmac: [:transformations, :hash, :format])
    
    # /transform/hash
    assert_equal '/O/hash', BobRoss.path('hash', optimize: true)
    assert_equal '/Hc109ec7293d935546fab58a51e7b925c1bda1b73O/hash', BobRoss.path('hash', optimize: true, hmac: true)
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059O/hash', BobRoss.path('hash', optimize: true, hmac: [:hash])
    assert_equal '/Hc109ec7293d935546fab58a51e7b925c1bda1b73O/hash', BobRoss.path('hash', optimize: true, hmac: [:transformations, :hash])
    assert_equal '/Hc109ec7293d935546fab58a51e7b925c1bda1b73O/hash', BobRoss.path('hash', optimize: true, hmac: [:transformations, :hash, :format])
    
    # /hash.format
    assert_equal '/P/hash.jpg', BobRoss.path('hash', progressive: true, format: :jpg)
    assert_equal '/Hb5a0ae0308467d83ee26f66c5e4c2874974c398fP/hash.jpg', BobRoss.path('hash', progressive: true, format: :jpg, hmac: true)
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059P/hash.jpg', BobRoss.path('hash', progressive: true, format: :jpg, hmac: [:hash])
    assert_equal '/Hb5a0ae0308467d83ee26f66c5e4c2874974c398fP/hash.jpg', BobRoss.path('hash', progressive: true, format: :jpg, hmac: [:transformations, :hash])
    assert_equal '/H9a8549ad413fac0c44bb8a2ef8a54aa8086734f5P/hash.jpg', BobRoss.path('hash', progressive: true, format: :jpg, hmac: [:transformations, :hash, :format])
    
    # /hash/filename
    assert_equal '/S500x500/hash/my+Filename%26', BobRoss.path('hash', resize: '500x500', filename: 'my Filename&')
    assert_equal '/He9f14c0ae58cf300d6b9655889c2661c591d7b4bS500x500/hash/my+Filename%26', BobRoss.path('hash', resize: '500x500', filename: 'my Filename&', hmac: true)
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059S500x500/hash/my+Filename%26', BobRoss.path('hash', resize: '500x500', filename: 'my Filename&', hmac: [:hash])
    assert_equal '/He9f14c0ae58cf300d6b9655889c2661c591d7b4bS500x500/hash/my+Filename%26', BobRoss.path('hash', resize: '500x500', filename: 'my Filename&', hmac: [:transformations, :hash])
    assert_equal '/He9f14c0ae58cf300d6b9655889c2661c591d7b4bS500x500/hash/my+Filename%26', BobRoss.path('hash', resize: '500x500', filename: 'my Filename&', hmac: [:transformations, :hash, :format])
    
    # /hash/filename.format
    assert_equal '/Baabbcc/hash/my+Filename%26.png', BobRoss.path('hash', background: 'aabbcc', filename: 'my Filename&', format: :png)
    assert_equal '/Hfae60e9eb00a16c19ff01aef0cadfe6709f024e6Baabbcc/hash/my+Filename%26.png', BobRoss.path('hash', background: 'aabbcc', filename: 'my Filename&', format: :png, hmac: true)
    assert_equal '/H41482f0113cc9843f0aeaa10631936644a164059Baabbcc/hash/my+Filename%26.png', BobRoss.path('hash', background: 'aabbcc', filename: 'my Filename&', format: :png, hmac: [:hash])
    assert_equal '/Hfae60e9eb00a16c19ff01aef0cadfe6709f024e6Baabbcc/hash/my+Filename%26.png', BobRoss.path('hash', background: 'aabbcc', filename: 'my Filename&', format: :png, hmac: [:transformations, :hash])
    assert_equal '/He993a4e6169a3effcfc7f2ea39ec56cc81a41591Baabbcc/hash/my+Filename%26.png', BobRoss.path('hash', background: 'aabbcc', filename: 'my Filename&', format: :png, hmac: [:transformations, :hash, :format])
  end
  
end