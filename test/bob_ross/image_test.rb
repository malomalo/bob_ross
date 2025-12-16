# frozen_string_literal: true

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

  test 'detects when an bw image is transparent' do
    image_path = File.expand_path('../../fixtures/bw-transparent.png', __FILE__)
    assert_equal(false, BobRoss.backend.identify(image_path)[:opaque])
    
    image = BobRoss::Image.new(File.open(image_path))
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
    image.transform(background: '#f5422a') do |output|
      assert_color '#f5422a', ::Vips::Image.new_from_file(output.path).getpoint(350, 350)
    end
  end

  test 'croping and image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    assert_transform(image, {crop: '100'}, {
      geometry: '100x100',
      signature: {
        im: {
          '>= 0.0' => 'db51d77baafd5baef53280b782552138966cb7e32d6be1ae884c9c30cf814c63'
        },
        vips: {
          '~> 8.14.5' => 'db51d77baafd5baef53280b782552138966cb7e32d6be1ae884c9c30cf814c63',
          '>= 8.15.0' => 'db51d77baafd5baef53280b782552138966cb7e32d6be1ae884c9c30cf814c63'
        }
      }
    })

    assert_transform(image, {crop: '100x50'}, {
      geometry: '100x50',
      signature: {
        im: {
          '>= 0.0' => '440b4343e7638b1d0d5b42c592e01664476364814b2edeb935455534cfb38e73'
        },
        vips: {
          '~> 8.14.5' => '440b4343e7638b1d0d5b42c592e01664476364814b2edeb935455534cfb38e73',
          '>= 8.15.0' => '440b4343e7638b1d0d5b42c592e01664476364814b2edeb935455534cfb38e73'
        }
      }
    })

    assert_transform(image, {crop: 'x50'}, {
      geometry: '50x50',
      signature: {
        im: {
          '>= 0.0' => '19f0eaee8a36e80d14623412c5c1f0ea01e57b8a9ec6e7310380f4b5101eb2ba'
        },
        vips: {
          '~> 8.14.5' => '19f0eaee8a36e80d14623412c5c1f0ea01e57b8a9ec6e7310380f4b5101eb2ba',
          '>= 8.15.0' => '19f0eaee8a36e80d14623412c5c1f0ea01e57b8a9ec6e7310380f4b5101eb2ba'
        }
      }
    })

    assert_transform(image, {crop: '200+200+50'}, {
      geometry: '200x200',
      signature: {
        im: {
          '>= 0.0' => '1ba29bf232d93a0ce8a1210a9bce21d1d1ee1a0f7d64a83a788532d17d2d7292'
        },
        vips: {
          '~> 8.14.5' => '1ba29bf232d93a0ce8a1210a9bce21d1d1ee1a0f7d64a83a788532d17d2d7292',
          '>= 8.15.0' => '1ba29bf232d93a0ce8a1210a9bce21d1d1ee1a0f7d64a83a788532d17d2d7292'
        }
      }
    })

    assert_transform(image, {crop: '200x100+200+50'}, {
      geometry: '200x100',
      signature: {
        im: {
          '>= 0.0' => '142e5f20f6a7be016d9df9b24a8aeb0654ab4eb500ac1e746c1c3731392e9221'
        },
        vips: {
          '~> 8.14.5' => '142e5f20f6a7be016d9df9b24a8aeb0654ab4eb500ac1e746c1c3731392e9221',
          '>= 8.15.0' => '142e5f20f6a7be016d9df9b24a8aeb0654ab4eb500ac1e746c1c3731392e9221'
        }
      }
    })

    assert_transform(image, {crop: 'x100+200+50'}, {
      geometry: '100x100',
      signature: {
        im: {
          '>= 0.0' => '95c2669f768ae2a1d5d822f4d9734b3089fd1395312b77ff7b32756a623b6ae4'
        },
        vips: {
          '~> 8.14.5' => '95c2669f768ae2a1d5d822f4d9734b3089fd1395312b77ff7b32756a623b6ae4',
          '>= 8.15.0' => '95c2669f768ae2a1d5d822f4d9734b3089fd1395312b77ff7b32756a623b6ae4'
        }
      }
    })

    assert_transform(image, {crop: '100c'}, {
      geometry: '100x100',
      signature: {
        im: {
          '>= 0.0' => 'db51d77baafd5baef53280b782552138966cb7e32d6be1ae884c9c30cf814c63'
        },
        vips: {
          '~> 8.14.5' => 'db51d77baafd5baef53280b782552138966cb7e32d6be1ae884c9c30cf814c63',
          '>= 8.15.0' => 'db51d77baafd5baef53280b782552138966cb7e32d6be1ae884c9c30cf814c63'
        }
      }
    })

    assert_transform(image, {crop: '100x50c'}, {
      geometry: '100x50',
      signature: {
        im: {
          '>= 0.0' => '440b4343e7638b1d0d5b42c592e01664476364814b2edeb935455534cfb38e73'
        },
        vips: {
          '~> 8.14.5' => '440b4343e7638b1d0d5b42c592e01664476364814b2edeb935455534cfb38e73',
          '>= 8.15.0' => '440b4343e7638b1d0d5b42c592e01664476364814b2edeb935455534cfb38e73'
        }
      }
    })

    assert_transform(image, {crop: 'x50c'}, {
      geometry: '50x50',
      signature: {
        im: {
          '>= 0.0' => '19f0eaee8a36e80d14623412c5c1f0ea01e57b8a9ec6e7310380f4b5101eb2ba'
        },
        vips: {
          '~> 8.14.5' => '19f0eaee8a36e80d14623412c5c1f0ea01e57b8a9ec6e7310380f4b5101eb2ba',
          '>= 8.15.0' => '19f0eaee8a36e80d14623412c5c1f0ea01e57b8a9ec6e7310380f4b5101eb2ba'
        }
      }
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
      signature: {
        im: {
          '>= 0.0' => '14563f90b1e4de152bbfb4b122fe289e431083b066e52f27a12bbda96154d487'
        },
        vips: {
          '~> 8.14.5' => '14563f90b1e4de152bbfb4b122fe289e431083b066e52f27a12bbda96154d487',
          '>= 8.15.0' => '14563f90b1e4de152bbfb4b122fe289e431083b066e52f27a12bbda96154d487'
        }
      }
    })

    assert_transform(image, {crop: '100ne'}, {
      geometry: '100x100',
      signature: {
        im: {
          '>= 0.0' => 'b1476aeb3e31fc30c500250d65d17343b0d3d275d017bc5be4e839096618efbb'
        },
        vips: {
          '~> 8.14.5' => 'b1476aeb3e31fc30c500250d65d17343b0d3d275d017bc5be4e839096618efbb',
          '>= 8.15.0' => 'b1476aeb3e31fc30c500250d65d17343b0d3d275d017bc5be4e839096618efbb'
        }
      }
    })

    assert_transform(image, {crop: '100e'}, {
      geometry: '100x100',
      signature: {
        im: {
          '>= 0.0' => 'ca425d00051269898775a41615aa5c11396887e4e274662b9ed89391ccdbdb14'
        },
        vips: {
          '~> 8.14.5' => 'ca425d00051269898775a41615aa5c11396887e4e274662b9ed89391ccdbdb14',
          '>= 8.15.0' => 'ca425d00051269898775a41615aa5c11396887e4e274662b9ed89391ccdbdb14'
        }
      }
    })

    assert_transform(image, {crop: '100se'}, {
      geometry: '100x100',
      signature: {
        im: {
          '>= 0.0' => 'd29b019e991a3cee8fe2b61317133fdf81b6a867bc609792a571ffa201efd849'
        },
        vips: {
          '~> 8.14.5' => 'd29b019e991a3cee8fe2b61317133fdf81b6a867bc609792a571ffa201efd849',
          '>= 8.15.0' => 'd29b019e991a3cee8fe2b61317133fdf81b6a867bc609792a571ffa201efd849'
        }
      }
    })

    assert_transform(image, {crop: '100s'}, {
      geometry: '100x100',
      signature: {
        im: {
          '>= 0.0' => 'cc61cdf71e2cabcd31dd04fd84042b0fc19b6cdedd23b43d50bee60f86b315bf'
        },
        vips: {
          '~> 8.14.5' => 'cc61cdf71e2cabcd31dd04fd84042b0fc19b6cdedd23b43d50bee60f86b315bf',
          '>= 8.15.0' => 'cc61cdf71e2cabcd31dd04fd84042b0fc19b6cdedd23b43d50bee60f86b315bf'
        }
      }
    })

    assert_transform(image, {crop: '100x100sw'}, {
      geometry: '100x100',
      signature: {
        im: {
          '>= 0.0' => '8389f9fb78fbe8eccb830ec0cea693a82e372bb1b8614c2d33de8249bacf8252'
        },
        vips: {
          '~> 8.14.5' => '8389f9fb78fbe8eccb830ec0cea693a82e372bb1b8614c2d33de8249bacf8252',
          '>= 8.15.0' => '8389f9fb78fbe8eccb830ec0cea693a82e372bb1b8614c2d33de8249bacf8252'
        }
      }
    })

    assert_transform(image, {crop: '100w'}, {
      geometry: '100x100',
      signature: {
        im: {
          '>= 0.0' => '816d9e5ec1a912601ce8079689151cc4766b645970f02fb53f28f17215878d8d'
        },
        vips: {
          '~> 8.14.5' => '816d9e5ec1a912601ce8079689151cc4766b645970f02fb53f28f17215878d8d',
          '>= 8.15.0' => '816d9e5ec1a912601ce8079689151cc4766b645970f02fb53f28f17215878d8d'
        }
      }
    })

    assert_transform(image, {crop: 'x100nw'}, {
      geometry: '100x100',
      signature: {
        im: {
          '>= 0.0' => 'e8439739ee560c25e208a8d073c89cd14ebd4256a697b84de6fa2054baaf75b7'
        },
        vips: {
          '~> 8.14.5' => '2653e04a1ce7b9cb657d70b91fb3d82c138bb49d7245c7061a0bdc46334441be',
          '>= 8.15.0' => '2653e04a1ce7b9cb657d70b91fb3d82c138bb49d7245c7061a0bdc46334441be'
        }
      }
    })
  end

  test 'grayscale an image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))

    assert_transform(image, {grayscale: true}, {
      geometry: '720x480',
      signature: {
        im: { '>= 0.0' => '8ad21be1b9563a20343357def4da37222eaf3f8508f160acf8d3413d0dd5d91d' },
        vips: {
          '>= 8.17.2' => 'd73357a77191e30392df2669932b3c3476bc34d9db6d966d5ddacbc9f534c6f3',
          '>= 8.14.5' => 'd2a99f9bb452b88fb524c428480ca9bbeb4012e5f7d927b147e9e889276fcaa7'
        }
      }
    })
  end

  test 'padding a transparent image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))

    assert_transform(image, {padding: '5'}, {
      geometry: '730x490',
      signature: {
        im: { '>= 0.0' => 'f618a277da1a306d3925d54db75515a995063fcf9278894cfe6a6e69cb800640' },
        vips: { '>= 8.14.5' => 'f618a277da1a306d3925d54db75515a995063fcf9278894cfe6a6e69cb800640' }
      }
    })

    assert_transform(image, {padding: '5wF3B902'}, {
      geometry: '730x490',
      signature: {
        im: { '>= 0.0' => '3b83d48f493795a57a76152c715632d40b783db7c12428b38ffbad05653b118b' },
        vips: { '>= 8.14.5' => '3b83d48f493795a57a76152c715632d40b783db7c12428b38ffbad05653b118b' }
      }
    })

    assert_transform(image, {padding: '10,5wF3B902'}, {
      geometry: '730x500',
      signature: {
        im: { '>= 0.0' => 'f9f2d025fb5fe8c976b07c1eedfb3c5d68e46d55127e33edc689d9f51da4467d' },
        vips: { '>= 8.14.5' => 'f9f2d025fb5fe8c976b07c1eedfb3c5d68e46d55127e33edc689d9f51da4467d' }
      }
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
      signature: {
        im: { '>= 0.0' => '77ca1d8f78d2ab5058c169650fe6f4321e8b8ef6d5101d8b68e078129e8bb319' },
        vips: { '>= 8.14.5' => '77ca1d8f78d2ab5058c169650fe6f4321e8b8ef6d5101d8b68e078129e8bb319' }
      }
    })
  end

  test 'padding an opaque image with output to a transparent image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/images_with_orientations/landscape-1', __FILE__)))
    image.transform({transparent: true, padding: '5'}, {format: 'image/png'}) do |output|
      # bnd = BobRoss.backend.name == 'BobRoss::ImageMagickBackend' ? 'imagemagick' : 'libvips'
      # `cp '#{output.path}' ~/test/image_test.253.#{bnd}#{File.extname(output.path)}`
      assert_signature({
        im: {
          '>= 7.1.1-17' => 'd3403b9baf8530b426f2ae1e745c68b8983ccb2459c1789240cbafc44a6f5692'
        },
        vips: {
          '>= 8.14.5' => 'd3403b9baf8530b426f2ae1e745c68b8983ccb2459c1789240cbafc44a6f5692'
        }
        }, output)
    end
  end

  test 'resize an image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))

    assert_transform(image, {resize: '100'}, {
      geometry: '100x67',
      signature: {
        im: {
          '>= 0.0' => 'b8428b80e19b60f18037e90f35de035b93f83c6f3bfd09ef4e088e2e6b7b8da1'
        },
        vips: {
          '>= 8.17.2' => '591ff3a8e116b4c97eff2dbb3ac377ddfa641788f926aa9501185f78785e9367',
          '>= 8.15.0' => '5c544d8fccbe3edf7d7c1aa4d04f1c53a27a5372e3feff2b082bcd4b97b887b6',
          '~> 8.14.5' => '5c86d9f437c1cbc9827b36d1c08d5bd4d8b31828786f194cd2a7f2fd125868c8',
        }
      }
    })

    assert_transform(image, {resize: 'x100'}, {
      geometry: '150x100',
      signature: {
        im: {
          '>= 0.0' => '6a119768c3135cfc8cd340fe273f765518512e99097da0961b7b80eb885a4e24'
        },
        vips: {
          '~> 8.14.5' => '6d1bd3539daa6de5e6cb8b97f1e90cc6e0c5694d0bc2abe0aa5fe01c27717ba7',
          '>= 8.15.0' => '8f90d6392ad4619047ff08c2776c1da5851bdb8b2ca1407d7946ecc2156a20bd'
        }
      }
    })

    assert_transform(image, {resize: '100x100'}, {
      geometry: '100x67',
      signature: {
        im: {
          '>= 0.0' => 'b8428b80e19b60f18037e90f35de035b93f83c6f3bfd09ef4e088e2e6b7b8da1'
        },
        vips: {
          '>= 8.17.2' => '591ff3a8e116b4c97eff2dbb3ac377ddfa641788f926aa9501185f78785e9367',
          '~> 8.14.5' => '5c86d9f437c1cbc9827b36d1c08d5bd4d8b31828786f194cd2a7f2fd125868c8',
          '>= 8.15.0' => '5c544d8fccbe3edf7d7c1aa4d04f1c53a27a5372e3feff2b082bcd4b97b887b6'
        }
      }
    })

    assert_transform(image, {resize: '100x100!'}, {
      geometry: '100x100',
      signature: {
        im: {
          '>= 0.0' => 'b6a9cbf02cf05ba5ea6531daa6084b181ab30f5a0a078b224241297fa19619af'
        },
        vips: {
          '>= 8.17.2' => 'e9280387950f7e066512cd8d080969b3883b72a1eeed6840be69a772e2b6f2e4',
          '~> 8.14.5' => 'fcd4f1025705227b31d1310fd8c4160c0669c4f31fd840d9b4107165ef55f07a',
          '>= 8.15.0' => '99a9c8f8a5c851f79be5eec3f59440ee450796d0319faf21d00e3cf82b08a366'
        }
      }
    })

    assert_transform(image, {resize: '1000x1000>'}, {
      geometry: '720x480',
      signature: {
        im: {
          '>= 0.0' => '6b24a3f88251d81dfcf8d70189d99c9ac0f86c8021b5453544c7dceb4f801dcc'
        },
        vips: {
          '~> 8.14.5' => 'e4dc89b908ea2b997b20abe8483f0f1f1f30241ed76aefcf51065ba9b5e5f8d6',
          '>= 8.15.0' => 'e4dc89b908ea2b997b20abe8483f0f1f1f30241ed76aefcf51065ba9b5e5f8d6'
        }
      }
    })

    assert_transform(image, {resize: '200x200>'}, {
      geometry: '200x133',
      signature: {
        im: {
          '>= 0.0' => '04e2b2b059aba5fa0a094fc9e96019e19502396dce8c411c5f82a29de70db96a'
        },
        vips: {
          '~> 8.14.5' => '47c34660701ddc02c5f18ba41392c3fe6188b1339c92d71ed324d3184d86173e',
          '>= 8.15.0' => 'bed1c9d8c5906f0ba5a5f6d3403c9f6f9da0c7d8ff9d74b0f84e360e3d89455f'
        }
      }
    })

    assert_transform(image, {resize: '800x800<'}, {
      geometry: '800x533',
      signature: {
        im: {
          '>= 0.0' => '308bb6ded0c87e2d28055f962e1a13123393593baca8f173b03b31bb33e09f2e'
        },
        vips: {
          '~> 8.14.5' => '500151ddb81f612a7416665d39513d032b93f9bfcccd8fd5240289cc171a1f9a',
          '>= 8.15.0' => '4b1426a106a2f6e79d8a2bbe9122da3515a192aec7ae6fecd2b5b0a101596ce9'
        }
      }
    })

    assert_transform(image, {resize: '200x200<'}, {
      geometry: '720x480',
      signature: {
        im: {
          '>= 0.0' => '6b24a3f88251d81dfcf8d70189d99c9ac0f86c8021b5453544c7dceb4f801dcc'
        },
        vips: {
          '~> 8.14.5' => 'e4dc89b908ea2b997b20abe8483f0f1f1f30241ed76aefcf51065ba9b5e5f8d6',
          '>= 8.15.0' => 'e4dc89b908ea2b997b20abe8483f0f1f1f30241ed76aefcf51065ba9b5e5f8d6'
        }
      }
    })

    assert_transform(image, {resize: '200x200#p0855AA'}, {
      geometry: '200x200',
      signature: {
        im: {
          '>= 0.0' => 'd0900a56baa9dc3ca3f3499263565eca2f3595023b999a1308cabc01f0266a74'
        },
        vips: {
          '~> 8.14.5' => '10927e09b94dffc29842d3e760d9a02c7e3ce7eef613aba45dcba1abe4297a56',
          '>= 8.15.0' => '5de8b4622261522141123e44f796e161f85e8efd59687c8d507ad2cd01fe8b1b'
        }
      }
    })

    assert_transform(image, {resize: '200x200*'}, {
      geometry: '200x200',
      signature: {
        im: {
          '>= 0.0' => 'f3209ac875fef39f31c0746cda7b80a65a05432534754cc7f6616d34128dc342'
        },
        vips: {
          '~> 8.14.5' => 'e2d39515596ec280e3f92b2f767ae90aec51c26b593e82214d023c8e45686aa4',
          '>= 8.15.0' => '010e011944c81414ada3a398fd9b5bdf89c0f62144a997557f147d63e6eb33c6'
        }
      }
    })

    assert_transform(image, {resize: '200x200*w'}, {
      geometry: '200x200',
      signature: {
        im: {
          '>= 0.0' => 'f887e8e7c293970bd73f3880395e2d03b9adfcd222b24331c95fa5bc679c5127'
        },
        vips: {
          '~> 8.14.5' => '1033fa0394f2d141f2fcf8ad40c6dfe9eb7f189a793101c8fef0ae75b5a87d78',
          '>= 8.15.0' => '686fbb2bc4def6bb3860589832dbdb014db302042afd261663525b31a9430583'
        }
      }
    })
  end

  test 'watermarking' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/opaque', __FILE__)))
    image.settings[:watermarks] = [File.expand_path('../../fixtures/watermark', __FILE__)].map do |path|
      { path: path, geometry: BobRoss.backend.identify(path)[:geometry] }
    end

    assert_transform(image, {watermark: '0n'}, {
      geometry: '720x480',
      signature: {
        im: {
          '>= 0.0' => '5a0b0ab61d3b4cbfd32eb7f2a273c3050dbee50504544b66158fca1b7c2a90f4'
        },
        vips: {
          '>= 8.17.2' => '524f669f4caf351cd8e36e0a54da55c3c503f96ae9a592c0608e35589963040a',
          '>= 8.15.0' => '24774ac82420a5654695f7ca146c71733e61e95ce4c0cdedf0d239fb10689a07',
          '~> 8.14.5' => 'd8150ea6d115d3c8efe057dadb29d14cab18632c79b793733c1e783123d3d550'
        }
      }
    })

    assert_transform(image, {watermark: '0e'}, {
      geometry: '720x480',
      signature: {
        im: {
          '>= 0.0' => '77830c630bc2b525a6eab6dc21c29867bf8ed94736ad9f286c0b3a14467dc7af'
        },
        vips: {
          '>= 8.17.2' => '37c0be06b3421bea9ab51932e3212406bd2c4462feed0eede7802a8bf46b4de5',
          '>= 8.15.0' => '620abf0752a762c5727136d55e7fa2b96da31299290393ab2bb15c7ca38acfc5',
          '~> 8.14.5' => '466e0a4bddc703ef20e204f231f527af790125258324a4c30887fd554469ffde'
        }
      }
    })

    assert_transform(image, {watermark: '0s'}, {
      geometry: '720x480',
      signature: {
        im: {
          '>= 0.0' => 'c69a96ee3caf1088bab040d5d90eb77b295c9fdbe8b99838eb124e4b9dcd2393'
        },
        vips: {
          '>= 8.17.2' => 'edc155f2a2fe2519927cb08fbb4510b4cc58b99187845b74c80ad5d20062d23b',
          '>= 8.15.0' => 'd2a0e072b88dd0cb46537e3b7934bd1bb2d3d035556905bf682f6a0c46df1dfd',
          '~> 8.14.5' => '12b5083c881fa9181b422b0401751b8cd67db8cb5dbd08e0b23b9c04975bf518'
        }
      }
    })

    assert_transform(image, {watermark: '0w'}, {
      geometry: '720x480',
      signature: {
        im: {
          '>= 0.0' => '7dac6b13a596cfaa4649f397c13e2edcf12e9e53e32df86c0a3567efe2ba8f7a'
        },
        vips: {
          '>= 8.17.2' => 'b40bda1c2328fa5dce1c357f2f5c5eded8a3849b1eca5279bdd6b7c50c516bb0',
          '>= 8.15.0' => '82e004da118cb0931a86e750466ec070fa8d9b1f9e5908bc7272f08955cb0ce4',
          '~> 8.14.5' => 'da1cbac5054ead31a5ae23b8c84bc0f98d6db0902dbbdcd0780ff33d71a2a0ef'
        }
      }
    })

    assert_transform(image, {watermark: '0c'}, {
      geometry: '720x480',
      signature: {
        im: {
          '>= 0.0' => '210c9b8732def89f30b49e14a00ba21f4dcb35e7773605a9b386656fad158521'
        },
        vips: {
          '>= 8.17.2' => 'bc418a3bb3083f4321b2968e96b3de894ee4e1c329b3f37a60bb462bbe5805b5',
          '>= 8.15.0' => '1eaaf1502d26ee066cc76d4af0cb5563871c831779c2f5fe3af4fad8618baec6',
          '~> 8.14.5' => '27615eca788c158171358c68eaa0659c9af36a8b8965d33368871b39e7dc3f12'
        }
      }
    })

    assert_transform(image, {watermark: '0ne'}, {
      geometry: '720x480',
      signature: {
        im: {
          '>= 0.0' => 'd29c63e1a86a5d196c04d86cf47a755f37e659571390695662e3a9f112b4b606'
        },
        vips: {
          '>= 8.17.2' => '791d60f1f62a6d8115d6885e286dc0f11362889bfe1d9a8585b72583ab2acba3',
          '>= 8.15.0' => 'e4049a5e63313ba6e61c53e83c481abfc223a31eb80571cf6671ee41652584bb',
          '~> 8.14.5' => '2199b4270d9d090851c7389aaa6d5d805fd0d8df7558a2dd76a00557a380d024'
        }
      }
    })

    assert_transform(image, {watermark: '0se'}, {
      geometry: '720x480',
      signature: {
        im: {
          '>= 0.0' => 'd818279a67ab1a67f8adc107e53f4e826b46ffb9a92cdfc50a77c6978d049bb2'
        },
        vips: {
          '>= 8.17.2' => '34ce093cdf99e36b1841207b58b5e41e0af5652c92fcee26a753889999fb69fe',
          '>= 8.15.0' => '035c0a3e51ebd66299b1aba2f5a64570b13b8782ceacf20697121903bccb46e9',
          '~> 8.14.5' => '6016482bcc48e09ae0dc59d26c3cc8b5a03867f5a23abfcdb51027077e8866ec'
        }
      }
    })

    assert_transform(image, {watermark: '0sw'}, {
      geometry: '720x480',
      signature: {
        im: {
          '>= 0.0' => 'bf30cbdb4a28347aab4e8e58bf8289392c7d7527e263ed6b6232674e40dc071b'
        },
        vips: {
          '>= 8.17.2' => 'a00746719cd3fff744727796ad9c390ca85a75a4992b450a74d52cb0ffd9e18e',
          '>= 8.15.0' => '812660e345c8169c021cb1b4d0321acd7fc1215c440ef26cf8ff4a0674255125',
          '~> 8.14.5' => '76164d3a1db2e3fe22fdae6c434526bf98361679c480c16d75f83d1a80e0622e'
        }
      }
    })

    assert_transform(image, {watermark: '0nw'}, {
      geometry: '720x480',
      signature: {
        im: {
          '>= 0.0' => 'b203550e214d3035e97202b57b72bbc4525b7bafbb71b1130f4ce0c411268dfd'
        },
        vips: {
          '>= 8.17.2' => 'a5ae0038f4232ce0dc0e3174c2a0239dc41abce8ca5a6acc6a738925f43eee5c',
          '>= 8.15.0' => 'ef7ad0a25671a25fb4351a3ccbd5cd10ff852c66922cdfce3c55653a05693c90',
          '~> 8.14.5' => 'b4d2817d7cbefedb2c55662319f9e85a9409f98509f7e738cb3a25e2446bc4a1'
        }
      }
    })

    assert_transform(image, {watermark: '0o'}, {
      geometry: '720x480',
      signature: {
        im: {
          '>= 0.0' => '3bc8daf0df761fc42eea4806aef4dea429569e0d739d2c30c57de387744455e0'
        },
        vips: {
          '>= 8.17.2' => '98168b0acda24fdd4f560fa61282e5ad652ac22b39d4e834e5eaaee092edf6fd',
          '>= 8.15.0' => '98168b0acda24fdd4f560fa61282e5ad652ac22b39d4e834e5eaaee092edf6fd',
          '~> 8.14.5' => 'c5702ec9cb41d1202c502c55fb16abfcb85a9a165bc0b356040c21c64ccff6ca'
        }
      }
    })
  end

end