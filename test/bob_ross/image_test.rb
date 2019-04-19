require 'ruby-vips'
require 'test_helper'

class BobRossImageTest < Minitest::Test
  
  test 'detects when an image is opaque' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    assert_equal true,  image.opaque
    assert_equal false, image.transparent
  end

  test 'detects when an image is transparent' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))
    assert_equal false, image.opaque
    assert_equal true,  image.transparent
  end

  test 'detects an image mime type' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))
    assert_equal 'image/png', image.mime_type.to_s
  end

  test 'detects image geometry' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))
    assert_equal({width: 720, height: 480, x_offset: nil, y_offset: nil, modifier: nil, gravity: nil, color: nil}, image.geometry)
  end

  test 'photo gets oriented before being processed' do
    1.upto(8) do |i|
      image = BobRoss::Image.new(File.open(File.expand_path("../../fixtures/images_with_orientations/landscape-#{i}", __FILE__)))
      assert_equal i, image.orientation

      image = BobRoss::Image.new(File.open(File.expand_path("../../fixtures/images_with_orientations/portrait-#{i}", __FILE__)))
      assert_equal i, image.orientation
    end
  end

  test 'background on a image with transparency' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))
    output = image.transform(background: '#f5422a')

    assert_color '#f5422a', ::Vips::Image.new_from_file(output.path).getpoint(350, 350)
  end

  test 'croping and image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    assert_transform(image, {crop: '100'}, {
      geometry: '100x100',
      signature: [
        'f20c92b54671bdbd6955bd90e32cb10d26e12ce0376c7a3e7055ea2c756299ce',
        'f20c92b54671bdbd6955bd90e32cb10d26e12ce0376c7a3e7055ea2c756299ce'
      ]
    })

    assert_transform(image, {crop: '100x50'}, {
      geometry: '100x50',
      signature: [
        'af925fc1167e45dd1fb894bc7f113d56f1afb98d46301614e81ee37137cb4a1f',
        'af925fc1167e45dd1fb894bc7f113d56f1afb98d46301614e81ee37137cb4a1f'
      ]
    })

    assert_transform(image, {crop: 'x50'}, {
      geometry: '50x50',
      signature: [
        '75765ff2934e5d7b6b82b800c2af0e4d3f7fbeac5c5c11cca7e548118ad75d4d',
        '75765ff2934e5d7b6b82b800c2af0e4d3f7fbeac5c5c11cca7e548118ad75d4d'
      ]
    })

    assert_transform(image, {crop: '200+200+50'}, {
      geometry: '200x200',
      signature: [
        'dacfb7adef43f6d009ad73580ad94fd6561b51b4f13a7be4fe16661af190469f',
        'dacfb7adef43f6d009ad73580ad94fd6561b51b4f13a7be4fe16661af190469f'
      ]
    })

    assert_transform(image, {crop: '200x100+200+50'}, {
      geometry: '200x100',
      signature: [
        'c98ceaffe12b5702ba1912ee3bea3abe85bb919cbfea395a9b3698785b9dcd9f',
        'c98ceaffe12b5702ba1912ee3bea3abe85bb919cbfea395a9b3698785b9dcd9f'
      ]
    })

    assert_transform(image, {crop: 'x100+200+50'}, {
      geometry: '100x100',
      signature: [
        '3e544347333079cb6cd8cdb275896cd296572e9732f0bc04353ca5f1fe150f57',
        '3e544347333079cb6cd8cdb275896cd296572e9732f0bc04353ca5f1fe150f57'
      ]
    })

    assert_transform(image, {crop: '100c'}, {
      geometry: '100x100',
      signature: [
        'f20c92b54671bdbd6955bd90e32cb10d26e12ce0376c7a3e7055ea2c756299ce',
        'f20c92b54671bdbd6955bd90e32cb10d26e12ce0376c7a3e7055ea2c756299ce'
      ]
    })

    assert_transform(image, {crop: '100x50c'}, {
      geometry: '100x50',
      signature: [
        'af925fc1167e45dd1fb894bc7f113d56f1afb98d46301614e81ee37137cb4a1f',
        'af925fc1167e45dd1fb894bc7f113d56f1afb98d46301614e81ee37137cb4a1f'
      ]
    })

    assert_transform(image, {crop: 'x50c'}, {
      geometry: '50x50',
      signature: [
        '75765ff2934e5d7b6b82b800c2af0e4d3f7fbeac5c5c11cca7e548118ad75d4d',
        '75765ff2934e5d7b6b82b800c2af0e4d3f7fbeac5c5c11cca7e548118ad75d4d'
      ]
    })

    # assert_transform(image, {crop: 'x100sm'}, {
    #   geometry: '100x100',
    #   signature: [
    #     '75765ff2934e5d7b6b82b800c2af0e4d3f7fbeac5c5c11cca7e548118ad75d4d',
    #     ''
    #   ]
    # })

    assert_transform(image, {crop: '100n'}, {
      geometry: '100x100',
      signature: [
        'dde47da620a35f9ecedc47a89ec2d18e007e0215ecdeebc6b4f1899b498ee0fb',
        'dde47da620a35f9ecedc47a89ec2d18e007e0215ecdeebc6b4f1899b498ee0fb'
      ]
    })

    assert_transform(image, {crop: '100ne'}, {
      geometry: '100x100',
      signature: [
        'b4eff08bb33598f8f01e943757ae8fec43353d9fb9688210c2240663964f57c4',
        'b4eff08bb33598f8f01e943757ae8fec43353d9fb9688210c2240663964f57c4'
      ]
    })

    assert_transform(image, {crop: '100e'}, {
      geometry: '100x100',
      signature: [
        '5068e42acaf241db061626bf34f6d26833ac36eb6e9e38ff7af2ceeeea330e7a',
        '5068e42acaf241db061626bf34f6d26833ac36eb6e9e38ff7af2ceeeea330e7a'
      ]
    })

    assert_transform(image, {crop: '100se'}, {
      geometry: '100x100',
      signature: [
        '585274c15135efaa5a0f64cbc0b027e4f7df778b0e9c0f52421f0ef0d67e2ba6',
        '585274c15135efaa5a0f64cbc0b027e4f7df778b0e9c0f52421f0ef0d67e2ba6'
      ]
    })

    assert_transform(image, {crop: '100s'}, {
      geometry: '100x100',
      signature: [
        '9afa8782eb605cac23254014080350aa2da575c25bf61eb170b847409c697904',
        '9afa8782eb605cac23254014080350aa2da575c25bf61eb170b847409c697904'
      ]
    })

    assert_transform(image, {crop: '100x100sw'}, {
      geometry: '100x100',
      signature: [
        'ab467ae2f6726473bc173b43540fc7528e0ce7851c272b1824041aa4f13dfb61',
        'ab467ae2f6726473bc173b43540fc7528e0ce7851c272b1824041aa4f13dfb61'
      ]
    })

    assert_transform(image, {crop: '100w'}, {
      geometry: '100x100',
      signature: [
        'fed38a9c56b4036dbbe655e4b024cc8dd324bf33478b2f043cfc4d321b6a31fa',
        'fed38a9c56b4036dbbe655e4b024cc8dd324bf33478b2f043cfc4d321b6a31fa'
      ]
    })

    assert_transform(image, {crop: 'x100nw'}, {
      geometry: '100x100',
      signature: [
        '997cab9acb6226ad6e56fe4c4552a010d3916b4e8ac4bd564670e67352751bf6',
        'c86b95626b6f3d0b34c58d16bf4ddb70140c88b72c599f7a1a05276a011ed2ae'
      ]
    })
  end

  test 'grayscale an image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    output = image.transform(grayscale: true)
    assert_signature([
      '0357d1cf6cc3162d5c634be3ee350b95593bb9adcf69f2bb6d61ae32bcfd9355',
      '9176c3dafd499e1d75fc53c25d092558cc6082683451689477a1db47fcb0d71e'
    ], output)
  end

  test 'padding an image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))

    assert_transform(image, {padding: '5'}, {
      geometry: '730x490',
      signature: [
        'a56f0d27236005a9f16f7bcece55925501739da64388699255f4b46e3cd53e66',
        'a56f0d27236005a9f16f7bcece55925501739da64388699255f4b46e3cd53e66'
      ]
    })

    assert_transform(image, {padding: '5wF3B902'}, {
      geometry: '730x490',
      signature: [
        '597456218e2159cad667cea3b8410c71a058a6e446b57e5fc7cd966aa0a9bf53',
        '597456218e2159cad667cea3b8410c71a058a6e446b57e5fc7cd966aa0a9bf53'
      ]
    })

    assert_transform(image, {padding: '10,5wF3B902'}, {
      geometry: '730x500',
      signature: [
        '1190195e2462846a070dba7ac3865b172b88279e802048a0af95db0c0adb63dc',
        '1190195e2462846a070dba7ac3865b172b88279e802048a0af95db0c0adb63dc'
      ]
    })

    # assert_transform(image, {padding: '20,10,5'}, {
    #   geometry: '740x505',
    #   signature: [
    #     '724bae36f7e684b4279e358d9e92fe135165ddcc080279c4287b751032e190f3',
    #     '724bae36f7e684b4279e358d9e92fe135165ddcc080279c4287b751032e190f3'
    #   ]
    # })

    assert_transform(image, {padding: '20,10,5,30w0855AA'}, {
      geometry: '760x505',
      signature: [
        'c04f8b53483c1b93e61da877d501502ea2f15e4555162820d9e1070c50eb3323',
        'c04f8b53483c1b93e61da877d501502ea2f15e4555162820d9e1070c50eb3323'
      ]
    })
  end
  
  test 'resize an image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))

    assert_transform(image, {resize: '100'}, {
      geometry: '100x67',
      signature: [
        'a3e7d9c21a80013d6cd3daace711c02f90519b927750fbd88b53b6cf5e8f2d70',
        'a59edf86bf3103006039848d3f3a9cb189c7eb35b252bb8afc742df3ea9d922b'
      ]
    })

    assert_transform(image, {resize: 'x100'}, {
      geometry: '150x100',
      signature: [
        '9c9d633689b401ace4c3fbd0781193e9e53d79c2ed00b26a4a6ea9407f54dad9',
        '43379539a60b58c1f1addeb6f54584c600127e53cadf1c73bbcdf9c11904b42d'
      ]
    })

    assert_transform(image, {resize: '100x100'}, {
      geometry: '100x67',
      signature: [
        'a3e7d9c21a80013d6cd3daace711c02f90519b927750fbd88b53b6cf5e8f2d70',
        'a59edf86bf3103006039848d3f3a9cb189c7eb35b252bb8afc742df3ea9d922b'
      ]
    })

    assert_transform(image, {resize: '100x100!'}, {
      geometry: '100x100',
      signature: [
        'f077c7bfd76699e25901e7bdd7c478eb78a556bde70c4455ccc253e25bdb040a',
        '18f2ba60e0c86fb60dc05ccead387c11b0be217e9ee9c6e1b2792aec913c0328'
      ]
    })

    assert_transform(image, {resize: '1000x1000>'}, {
      geometry: '720x480',
      signature: [
        '783b1185d8774ef22b50bb71a19aadc7eac33816c7f11d9cf9f2c1919a5b843e',
        'e0d044fc3d7cb9297ca4260ff23c09dff74df3a7f5ff7f2ca069c49c4a58ce58'
      ]
    })

    assert_transform(image, {resize: '200x200>'}, {
      geometry: '200x133',
      signature: [
        '4e1e1240c684b59aed6d60594f1559ab5e6389aa351fcc4dc0ca89b5b9f7963d',
        '54ec0a2d4f268b6e6fda7e782a9d442b7af97e5d28a74b023511d903a0bf5f09'
      ]
    })

    assert_transform(image, {resize: '800x800<'}, {
      geometry: '800x533',
      signature: [
        '170baaa8ccdc062cab2aaf33ffc6e3bd68796326c4ec4ef9c09ce42c15ffaa27',
        'e2a1eaf1f76caec02c96bcac651d00578a14238fc41815765c3a899550c2a235'
      ]
    })

    assert_transform(image, {resize: '200x200<'}, {
      geometry: '720x480',
      signature: [
        '783b1185d8774ef22b50bb71a19aadc7eac33816c7f11d9cf9f2c1919a5b843e',
        'e0d044fc3d7cb9297ca4260ff23c09dff74df3a7f5ff7f2ca069c49c4a58ce58'
      ]
    })

    assert_transform(image, {resize: '200x200#p0855AA'}, {
      geometry: '200x200',
      signature: [
        'f37afda6e0d1c76981782cf461f35d759a0aabeb45e1cce506c4c550ca929a3a',
        'f2ad828e373c28ad17029d0313e939a8bd8313871819d93df32bd4af8bf10b51'
      ]
    })

    assert_transform(image, {resize: '200x200*'}, {
      geometry: '200x200',
      signature: [
        '1803482520b26c29f17ad27d841fa597f3ddba57926186d300cf8b63bb77b764',
        '26dc0cbd0da02f0286d3408a49f0a281787993a6b0455c304109559c2be155d6'
      ]
    })

    assert_transform(image, {resize: '200x200*w'}, {
      geometry: '200x200',
      signature: [
        '5805d50ab04023c83c3e43f5b653712dfa0c494519f197c604cb071eb87baa68',
        '1525740edcfd356b83dff177add3e9eb3f918684f432f8e84765425146ca9aa9'
      ]
    })
  end

  test 'watermarking' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    image.settings[:watermarks] = [File.expand_path('../../fixtures/watermark', __FILE__)].map do |path|
      { path: path, geometry: BobRoss.backend.identify(path)[:geometry] }
    end

    assert_transform(image, {watermark: '0n'}, {
      geometry: '720x480',
      signature: [
        'c569ed3bfc47cda3f5e2d859acc7776d50aba0e1ca40b84cd0ade4f4509f2c0a',
        'fa1e604695d2d25b6915755cb9b45c2e0fec02c3c307755ff532b5edee2fee69'
      ]
    })

    assert_transform(image, {watermark: '0e'}, {
      geometry: '720x480',
      signature: [
        'c13c7f62b1dcda8de82fefa7c424a50589eeadfe6ea0abbe17b7b1de2af63728',
        '4dec02a6875b2387368ab1b1aca5433b4025b9a9ac9d9a5c9d6c1f80ffc39a96'
      ]
    })

    assert_transform(image, {watermark: '0s'}, {
      geometry: '720x480',
      signature: [
        'b5dc4834a26a8291ec0be8399e398c5d7a8789e4aa068beac47a4477f6aa41e5',
        'b9413ee9a55875d52808f97a8f92b28b42b19ae5e9b4893895101d08601777c7'
      ]
    })

    assert_transform(image, {watermark: '0w'}, {
      geometry: '720x480',
      signature: [
        '168cd8bfd4db6920949ed87e559501c1c93bbd93f8556b0b0438acf74fed4634',
        'a0c08a5318ee0dcf16496481d3a725762aa6d22618119fca2c178f9e066f8b2d'
      ]
    })

    assert_transform(image, {watermark: '0c'}, {
      geometry: '720x480',
      signature: [
        '4af97fcd0d2d6af0309196acea1793d8188b87c0442e75d2fd5cf5f07b8dbb68',
        '3844013d78fb3361675750252199ae641c557902b67691f530a03ca2918eecce'
      ]
    })

    assert_transform(image, {watermark: '0ne'}, {
      geometry: '720x480',
      signature: [
        '53599ad0db4051d96a07087b6665354eb534030b1b045ea359a4a5ce1f6e6a75',
        'df82c048777ac64a78668a76fa19286a57a2953339e687d7bc725c28a967c7e5'
      ]
    })

    assert_transform(image, {watermark: '0se'}, {
      geometry: '720x480',
      signature: [
        'f5cf5a614d77104d37acd1e6ae9f853209208d9e173a88f4731fce8ee41a8b45',
        '10179f3d5f4a356ec961c7341c5a26e3532cbf526f08effc3f22527348c7a982'
      ]
    })

    assert_transform(image, {watermark: '0sw'}, {
      geometry: '720x480',
      signature: [
        'ea0abef2a73d08a705ad8f6d09ec00425809280fedbdd55efa49d559f2a200a6',
        '925fe94d60e08ffcfc38faf0dac6f92d757accebbb53efa4743dcb030b871f80'
      ]
    })

    assert_transform(image, {watermark: '0nw'}, {
      geometry: '720x480',
      signature: [
        '9d3f86041a3d8960f4a912dae60ace403891349542a09a6c1e7e0411853ef476',
        '14d58191de4a22e23547837a5a3dc74eec915c3dfd48f3d4c2a1ad3121f5c6fd'
      ]
    })

    assert_transform(image, {watermark: '0o'}, {
      geometry: '720x480',
      signature: [
        'e4273d32e82c7e789285328865545aed40a98ff61da819a8ece674f17cc05cbe',
        '996ae1486775142660d1f5926b671038526e0512c2d2fb7c9da662514678a73c'
      ]
    })
  end

end