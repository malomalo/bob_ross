require 'test_helper'

class BobRossTest < Minitest::Test
  
  def setup
    BobRoss.secret_key = 'secret'
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
    assert_equal '/hash', BobRoss.url('hash')
    assert_equal '/H678bd2c1ad2eb6ee1d13d42585e28dda995f1e49/hash', BobRoss.url('hash', hmac: true)
    
    # /hash.format
    assert_equal '/hash.jpg', BobRoss.url('hash', format: :jpg)
    assert_equal '/Hbaac51e04a0cc7395be489d09f00b25a4a4e34c4/hash.jpg', BobRoss.url('hash', format: :jpg, hmac: true)
    
    # /hash/filename
    assert_equal '/hash/my+Filename%26', BobRoss.url('hash', filename: 'my Filename&')
    assert_equal '/H0d516715d16fa0fed8498ec9c7db7cc6599dbf01/hash/my+Filename%26', BobRoss.url('hash', filename: 'my Filename&', hmac: true)
    
    # /hash/filename.format
    assert_equal '/hash/my+Filename%26.png', BobRoss.url('hash', filename: 'my Filename&', format: :png)
    assert_equal '/Hd568ea492d180156d5d625c88b9b420c32f9f17e/hash/my+Filename%26.png', BobRoss.url('hash', filename: 'my Filename&', format: :png, hmac: true)
    
    # /transform/hash
    assert_equal '/O/hash', BobRoss.url('hash', optimize: true)
    assert_equal '/H8810bbeca3413a79a0bdb40a404a87ec956d3b68O/hash', BobRoss.url('hash', optimize: true, hmac: true)
    
    # /hash.format
    assert_equal '/P/hash.jpg', BobRoss.url('hash', progressive: true, format: :jpg)
    assert_equal '/Ha86b8bf21c71b5dca44d8de0aa3448aaf73b02e9P/hash.jpg', BobRoss.url('hash', progressive: true, format: :jpg, hmac: true)
    
    # /hash/filename
    assert_equal '/S500x500/hash/my+Filename%26', BobRoss.url('hash', resize: '500x500', filename: 'my Filename&')
    assert_equal '/H7b536a7d4cca4762d8e0b397bda19ea62ccea129S500x500/hash/my+Filename%26', BobRoss.url('hash', resize: '500x500', filename: 'my Filename&', hmac: true)
    
    # /hash/filename.format
    assert_equal '/Baabbcc/hash/my+Filename%26.png', BobRoss.url('hash', background: 'aabbcc', filename: 'my Filename&', format: :png)
    assert_equal '/Hfd2852a7f71f34625547f6edccf8d50d9dd11529Baabbcc/hash/my+Filename%26.png', BobRoss.url('hash', background: 'aabbcc', filename: 'my Filename&', format: :png, hmac: true)
  end
  
end