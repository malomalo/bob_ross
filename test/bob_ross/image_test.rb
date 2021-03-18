require 'ruby-vips'
require 'test_helper'

class BobRossImageTest < Minitest::Test
  
  test 'detects when an image is opaque' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    assert_equal true,  image.opaque
    assert_equal false, image.transparent?
  end

  test 'detects when an image is transparent' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))
    assert_equal false, image.opaque
    assert_equal true,  image.transparent?
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
        'db51d77baafd5baef53280b782552138966cb7e32d6be1ae884c9c30cf814c63',
        'db51d77baafd5baef53280b782552138966cb7e32d6be1ae884c9c30cf814c63'
      ]
    })

    assert_transform(image, {crop: '100x50'}, {
      geometry: '100x50',
      signature: [
        '440b4343e7638b1d0d5b42c592e01664476364814b2edeb935455534cfb38e73',
        '440b4343e7638b1d0d5b42c592e01664476364814b2edeb935455534cfb38e73'
      ]
    })

    assert_transform(image, {crop: 'x50'}, {
      geometry: '50x50',
      signature: [
        '19f0eaee8a36e80d14623412c5c1f0ea01e57b8a9ec6e7310380f4b5101eb2ba',
        '19f0eaee8a36e80d14623412c5c1f0ea01e57b8a9ec6e7310380f4b5101eb2ba'
      ]
    })

    assert_transform(image, {crop: '200+200+50'}, {
      geometry: '200x200',
      signature: [
        '1ba29bf232d93a0ce8a1210a9bce21d1d1ee1a0f7d64a83a788532d17d2d7292',
        '1ba29bf232d93a0ce8a1210a9bce21d1d1ee1a0f7d64a83a788532d17d2d7292'
      ]
    })

    assert_transform(image, {crop: '200x100+200+50'}, {
      geometry: '200x100',
      signature: [
        '142e5f20f6a7be016d9df9b24a8aeb0654ab4eb500ac1e746c1c3731392e9221',
        '142e5f20f6a7be016d9df9b24a8aeb0654ab4eb500ac1e746c1c3731392e9221'
      ]
    })

    assert_transform(image, {crop: 'x100+200+50'}, {
      geometry: '100x100',
      signature: [
        '95c2669f768ae2a1d5d822f4d9734b3089fd1395312b77ff7b32756a623b6ae4',
        '95c2669f768ae2a1d5d822f4d9734b3089fd1395312b77ff7b32756a623b6ae4'
      ]
    })

    assert_transform(image, {crop: '100c'}, {
      geometry: '100x100',
      signature: [
        'db51d77baafd5baef53280b782552138966cb7e32d6be1ae884c9c30cf814c63',
        'db51d77baafd5baef53280b782552138966cb7e32d6be1ae884c9c30cf814c63'
      ]
    })

    assert_transform(image, {crop: '100x50c'}, {
      geometry: '100x50',
      signature: [
        '440b4343e7638b1d0d5b42c592e01664476364814b2edeb935455534cfb38e73',
        '440b4343e7638b1d0d5b42c592e01664476364814b2edeb935455534cfb38e73'
      ]
    })

    assert_transform(image, {crop: 'x50c'}, {
      geometry: '50x50',
      signature: [
        '19f0eaee8a36e80d14623412c5c1f0ea01e57b8a9ec6e7310380f4b5101eb2ba',
        '19f0eaee8a36e80d14623412c5c1f0ea01e57b8a9ec6e7310380f4b5101eb2ba'
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
        '14563f90b1e4de152bbfb4b122fe289e431083b066e52f27a12bbda96154d487',
        '14563f90b1e4de152bbfb4b122fe289e431083b066e52f27a12bbda96154d487'
      ]
    })

    assert_transform(image, {crop: '100ne'}, {
      geometry: '100x100',
      signature: [
        'b1476aeb3e31fc30c500250d65d17343b0d3d275d017bc5be4e839096618efbb',
        'b1476aeb3e31fc30c500250d65d17343b0d3d275d017bc5be4e839096618efbb'
      ]
    })

    assert_transform(image, {crop: '100e'}, {
      geometry: '100x100',
      signature: [
        'ca425d00051269898775a41615aa5c11396887e4e274662b9ed89391ccdbdb14',
        'ca425d00051269898775a41615aa5c11396887e4e274662b9ed89391ccdbdb14'
      ]
    })

    assert_transform(image, {crop: '100se'}, {
      geometry: '100x100',
      signature: [
        'd29b019e991a3cee8fe2b61317133fdf81b6a867bc609792a571ffa201efd849',
        'd29b019e991a3cee8fe2b61317133fdf81b6a867bc609792a571ffa201efd849'
      ]
    })

    assert_transform(image, {crop: '100s'}, {
      geometry: '100x100',
      signature: [
        'cc61cdf71e2cabcd31dd04fd84042b0fc19b6cdedd23b43d50bee60f86b315bf',
        'cc61cdf71e2cabcd31dd04fd84042b0fc19b6cdedd23b43d50bee60f86b315bf'
      ]
    })

    assert_transform(image, {crop: '100x100sw'}, {
      geometry: '100x100',
      signature: [
        '8389f9fb78fbe8eccb830ec0cea693a82e372bb1b8614c2d33de8249bacf8252',
        '8389f9fb78fbe8eccb830ec0cea693a82e372bb1b8614c2d33de8249bacf8252'
      ]
    })

    assert_transform(image, {crop: '100w'}, {
      geometry: '100x100',
      signature: [
        '816d9e5ec1a912601ce8079689151cc4766b645970f02fb53f28f17215878d8d',
        '816d9e5ec1a912601ce8079689151cc4766b645970f02fb53f28f17215878d8d'
      ]
    })

    assert_transform(image, {crop: 'x100nw'}, {
      geometry: '100x100',
      signature: [
        'e8439739ee560c25e208a8d073c89cd14ebd4256a697b84de6fa2054baaf75b7',
        '2653e04a1ce7b9cb657d70b91fb3d82c138bb49d7245c7061a0bdc46334441be'
      ]
    })
  end

  test 'grayscale an image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    assert_transform(image, {grayscale: true}, {
      geometry: '720x480',
      signature: [
        '8ad21be1b9563a20343357def4da37222eaf3f8508f160acf8d3413d0dd5d91d',
        'd2a99f9bb452b88fb524c428480ca9bbeb4012e5f7d927b147e9e889276fcaa7'
      ]
    })
  end

  test 'padding a transparent image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))

    assert_transform(image, {padding: '5'}, {
      geometry: '730x490',
      signature: [
        'f618a277da1a306d3925d54db75515a995063fcf9278894cfe6a6e69cb800640',
        'f618a277da1a306d3925d54db75515a995063fcf9278894cfe6a6e69cb800640'
      ]
    })

    assert_transform(image, {padding: '5wF3B902'}, {
      geometry: '730x490',
      signature: [
        '3b83d48f493795a57a76152c715632d40b783db7c12428b38ffbad05653b118b',
        '3b83d48f493795a57a76152c715632d40b783db7c12428b38ffbad05653b118b'
      ]
    })

    assert_transform(image, {padding: '10,5wF3B902'}, {
      geometry: '730x500',
      signature: [
        'f9f2d025fb5fe8c976b07c1eedfb3c5d68e46d55127e33edc689d9f51da4467d',
        'f9f2d025fb5fe8c976b07c1eedfb3c5d68e46d55127e33edc689d9f51da4467d'
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
        '77ca1d8f78d2ab5058c169650fe6f4321e8b8ef6d5101d8b68e078129e8bb319',
        '77ca1d8f78d2ab5058c169650fe6f4321e8b8ef6d5101d8b68e078129e8bb319'
      ]
    })
  end

  test 'padding an opaque image with output to a transparent image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/images_with_orientations/landscape-1', __FILE__)))
    output = image.transform({transparent: true, padding: '5'}, {format: 'image/png'})
    # bnd = BobRoss.backend.name == 'BobRoss::ImageMagickBackend' ? 'imagemagick' : 'libvips'
    # `cp '#{output.path}' ~/test/image_test.255.#{bnd}#{File.extname(output.path)}`
    assert_signature([
      'b5166aeaf8466d88459f4fbfeaffd8cc0dc8994ed978415971f8bceedb4bec5b',
      'd3403b9baf8530b426f2ae1e745c68b8983ccb2459c1789240cbafc44a6f5692'
    ], output)
  end

  test 'resize an image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))

    assert_transform(image, {resize: '100'}, {
      geometry: '100x67',
      signature: [
        'b8428b80e19b60f18037e90f35de035b93f83c6f3bfd09ef4e088e2e6b7b8da1',
        'c39e3f0612cdf56c3354d632e9dbbb7bcc8bd8408b19d7cd226126e744115aaa'
      ]
    })

    assert_transform(image, {resize: 'x100'}, {
      geometry: '150x100',
      signature: [
        '6a119768c3135cfc8cd340fe273f765518512e99097da0961b7b80eb885a4e24',
        'ba2a72f86332cf5f0bc2146040d1925b340a22ab831a352ec5e713379ee1c108'
      ]
    })

    assert_transform(image, {resize: '100x100'}, {
      geometry: '100x67',
      signature: [
        'b8428b80e19b60f18037e90f35de035b93f83c6f3bfd09ef4e088e2e6b7b8da1',
        'c39e3f0612cdf56c3354d632e9dbbb7bcc8bd8408b19d7cd226126e744115aaa'
      ]
    })

    assert_transform(image, {resize: '100x100!'}, {
      geometry: '100x100',
      signature: [
        'b6a9cbf02cf05ba5ea6531daa6084b181ab30f5a0a078b224241297fa19619af',
        'bb90253f26775ec23e90c4465306da6a4ac1e1b18f4c14f1b1286b263373c885'
      ]
    })

    assert_transform(image, {resize: '1000x1000>'}, {
      geometry: '720x480',
      signature: [
        '6b24a3f88251d81dfcf8d70189d99c9ac0f86c8021b5453544c7dceb4f801dcc',
        'e4dc89b908ea2b997b20abe8483f0f1f1f30241ed76aefcf51065ba9b5e5f8d6'
      ]
    })

    assert_transform(image, {resize: '200x200>'}, {
      geometry: '200x133',
      signature: [
        '04e2b2b059aba5fa0a094fc9e96019e19502396dce8c411c5f82a29de70db96a',
        '53446dc48de4b954252e9ca03a3022fb05cf1dab24b0cd2f5e89e2f6f5084b58'
      ]
    })

    assert_transform(image, {resize: '800x800<'}, {
      geometry: '800x533',
      signature: [
        '308bb6ded0c87e2d28055f962e1a13123393593baca8f173b03b31bb33e09f2e',
        '500151ddb81f612a7416665d39513d032b93f9bfcccd8fd5240289cc171a1f9a'
      ]
    })

    assert_transform(image, {resize: '200x200<'}, {
      geometry: '720x480',
      signature: [
        '6b24a3f88251d81dfcf8d70189d99c9ac0f86c8021b5453544c7dceb4f801dcc',
        'e4dc89b908ea2b997b20abe8483f0f1f1f30241ed76aefcf51065ba9b5e5f8d6'
      ]
    })

    assert_transform(image, {resize: '200x200#p0855AA'}, {
      geometry: '200x200',
      signature: [
        '69a200e57445da54086a78838252ae24b9b9e6c1f0e3496368fb0be89ae73bc4',
        '6cbf8367ca117379cbe93f4d7e1da51d9def5910f42fe6f863b6145ab692f081'
      ]
    })

    assert_transform(image, {resize: '200x200*'}, {
      geometry: '200x200',
      signature: [
        'f3209ac875fef39f31c0746cda7b80a65a05432534754cc7f6616d34128dc342',
        '9603566efc107c75c7e48bba736ff5c2e73639c6bb9d7c541ccc0b6d2f5e8904'
      ]
    })

    assert_transform(image, {resize: '200x200*w'}, {
      geometry: '200x200',
      signature: [
        'f887e8e7c293970bd73f3880395e2d03b9adfcd222b24331c95fa5bc679c5127',
        '58ddee7ed63418c00da0502bb9e7917c164e1275d155bdff8b2feac0e16a280c'
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
        '5a0b0ab61d3b4cbfd32eb7f2a273c3050dbee50504544b66158fca1b7c2a90f4',
        'db980c1fce16fd9067ec40f700f88ac6b869dc1106ec03829c8ad87bfd2c03c8'
      ]
    })

    assert_transform(image, {watermark: '0e'}, {
      geometry: '720x480',
      signature: [
        '77830c630bc2b525a6eab6dc21c29867bf8ed94736ad9f286c0b3a14467dc7af',
        'cd086f2d95bc20750aab6403bf9035b7b6b5ec0253c39a0702794554d39d5625'
      ]
    })

    assert_transform(image, {watermark: '0s'}, {
      geometry: '720x480',
      signature: [
        'c69a96ee3caf1088bab040d5d90eb77b295c9fdbe8b99838eb124e4b9dcd2393',
        '1ee816239f17bf0ff6d041b4981726a0e68b0cbef774472ceec848477ade71f2'
      ]
    })

    assert_transform(image, {watermark: '0w'}, {
      geometry: '720x480',
      signature: [
        '7dac6b13a596cfaa4649f397c13e2edcf12e9e53e32df86c0a3567efe2ba8f7a',
        '0967a51465835ca28aabd5830d01568c28faa3748cfb162e865d23014a4965df'
      ]
    })

    assert_transform(image, {watermark: '0c'}, {
      geometry: '720x480',
      signature: [
        '210c9b8732def89f30b49e14a00ba21f4dcb35e7773605a9b386656fad158521',
        '2e53eb526688724611c4ed032d0ac3cc4385bef04ede764df8e7877379ab601c'
      ]
    })

    assert_transform(image, {watermark: '0ne'}, {
      geometry: '720x480',
      signature: [
        'd29c63e1a86a5d196c04d86cf47a755f37e659571390695662e3a9f112b4b606',
        '6db451d0ff46afad134c46d838bb673843110e96206337d07c8990b0f92a8a2c'
      ]
    })

    assert_transform(image, {watermark: '0se'}, {
      geometry: '720x480',
      signature: [
        'd818279a67ab1a67f8adc107e53f4e826b46ffb9a92cdfc50a77c6978d049bb2',
        'c3cccfcd8496273e6da69e4c002e99a6c0f1acd7464405e3a5ff9488aca75283'
      ]
    })

    assert_transform(image, {watermark: '0sw'}, {
      geometry: '720x480',
      signature: [
        'bf30cbdb4a28347aab4e8e58bf8289392c7d7527e263ed6b6232674e40dc071b',
        'e5781c478e9a694ca0fef137bf340660635178127e5611c84824aaaa87f50bea'
      ]
    })

    assert_transform(image, {watermark: '0nw'}, {
      geometry: '720x480',
      signature: [
        'b203550e214d3035e97202b57b72bbc4525b7bafbb71b1130f4ce0c411268dfd',
        '1593edfca341c4b6a9e3fa0466d94da68d6f53bf79e083d50ae1e86fcdee7c84'
      ]
    })

    assert_transform(image, {watermark: '0o'}, {
      geometry: '720x480',
      signature: [
        'add7d6ea1fc4ae3ebd0a80f2d40dedfc07fd5a382981c5de063ad062b15de238',
        '4f798c285d89c346a4931b87338bbc76ab14242d027e677d65cb15938bfe5a0d'
      ]
    })
  end

end