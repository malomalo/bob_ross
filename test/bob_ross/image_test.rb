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
        '08760c33048af26ab9d5ff9afd2888ee327c4118b0a2b24a9b53dbc1a6c0e36b',
        '08760c33048af26ab9d5ff9afd2888ee327c4118b0a2b24a9b53dbc1a6c0e36b'
      ]
    })

    assert_transform(image, {crop: '100x50'}, {
      geometry: '100x50',
      signature: [
        '576ce960a22b921fb8b0b92bb0f13a1308aa94d4804e487431739c4b4348b9e3',
        '576ce960a22b921fb8b0b92bb0f13a1308aa94d4804e487431739c4b4348b9e3'
      ]
    })

    assert_transform(image, {crop: 'x50'}, {
      geometry: '50x50',
      signature: [
        '39771494df5ca3246892ef5325244591cea57517e88181a7bf8f4ab65f820283',
        '39771494df5ca3246892ef5325244591cea57517e88181a7bf8f4ab65f820283'
      ]
    })

    assert_transform(image, {crop: '200+200+50'}, {
      geometry: '200x200',
      signature: [
        'e34c8bbe396e7f816dcea5a26cbbbea95a4e76e0c16731e4e3b86f13d56471e1',
        'e34c8bbe396e7f816dcea5a26cbbbea95a4e76e0c16731e4e3b86f13d56471e1'
      ]
    })

    assert_transform(image, {crop: '200x100+200+50'}, {
      geometry: '200x100',
      signature: [
        'fded60a540ff31b295919bd90bdf39be14a11e07510ecdf33ae997d3df4d3f65',
        'fded60a540ff31b295919bd90bdf39be14a11e07510ecdf33ae997d3df4d3f65'
      ]
    })

    assert_transform(image, {crop: 'x100+200+50'}, {
      geometry: '100x100',
      signature: [
        'cd5a82d6d0622c1fa0fab235f9bfbf2d433d677f751022e657f082772288f991',
        'cd5a82d6d0622c1fa0fab235f9bfbf2d433d677f751022e657f082772288f991'
      ]
    })

    assert_transform(image, {crop: '100c'}, {
      geometry: '100x100',
      signature: [
        '08760c33048af26ab9d5ff9afd2888ee327c4118b0a2b24a9b53dbc1a6c0e36b',
        '08760c33048af26ab9d5ff9afd2888ee327c4118b0a2b24a9b53dbc1a6c0e36b'
      ]
    })

    assert_transform(image, {crop: '100x50c'}, {
      geometry: '100x50',
      signature: [
        '576ce960a22b921fb8b0b92bb0f13a1308aa94d4804e487431739c4b4348b9e3',
        '576ce960a22b921fb8b0b92bb0f13a1308aa94d4804e487431739c4b4348b9e3'
      ]
    })

    assert_transform(image, {crop: 'x50c'}, {
      geometry: '50x50',
      signature: [
        '39771494df5ca3246892ef5325244591cea57517e88181a7bf8f4ab65f820283',
        '39771494df5ca3246892ef5325244591cea57517e88181a7bf8f4ab65f820283'
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
        'b74e5268b1234cb5774b4626b6d6ecf822b6480a04a431279840eb45b14ad109',
        'b74e5268b1234cb5774b4626b6d6ecf822b6480a04a431279840eb45b14ad109'
      ]
    })

    assert_transform(image, {crop: '100ne'}, {
      geometry: '100x100',
      signature: [
        '1ee65cf86b5fe468a801314570cb89dde5907240355d35677c65a5ea5ad37d34',
        '1ee65cf86b5fe468a801314570cb89dde5907240355d35677c65a5ea5ad37d34'
      ]
    })

    assert_transform(image, {crop: '100e'}, {
      geometry: '100x100',
      signature: [
        'eec983c9a09cf587a8af8bc0f658b06db88d25ef79d6105d1e7d8607de254244',
        'eec983c9a09cf587a8af8bc0f658b06db88d25ef79d6105d1e7d8607de254244'
      ]
    })

    assert_transform(image, {crop: '100se'}, {
      geometry: '100x100',
      signature: [
        '3224850dceeed313ee4542c89bc83c54d40d9925af0dcdbbcff3b53e93426dc3',
        '3224850dceeed313ee4542c89bc83c54d40d9925af0dcdbbcff3b53e93426dc3'
      ]
    })

    assert_transform(image, {crop: '100s'}, {
      geometry: '100x100',
      signature: [
        '7d812eb683726a5169725b7bb27324ab1c51cc7c4c863c72c54c307fcac7d81c',
        '7d812eb683726a5169725b7bb27324ab1c51cc7c4c863c72c54c307fcac7d81c'
      ]
    })

    assert_transform(image, {crop: '100x100sw'}, {
      geometry: '100x100',
      signature: [
        '74411f71f0ce454ce0f6ac086ffdf7ad7b2bd0cea2f06851460edabcdcf65382',
        '74411f71f0ce454ce0f6ac086ffdf7ad7b2bd0cea2f06851460edabcdcf65382'
      ]
    })

    assert_transform(image, {crop: '100w'}, {
      geometry: '100x100',
      signature: [
        '3da648ece980ab7a263eea0f89bebc8ba24a530a84a821199c312b2a08f155d7',
        '3da648ece980ab7a263eea0f89bebc8ba24a530a84a821199c312b2a08f155d7'
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
        '6efd48e7b4bb81ef7da514fcacb73d1eba0a992a971973a1aff7c3e209608c17',
        '6e4c09e04f287b5d4e3cb0b9d30b829fa3afb53d01c2d9105b6d8ed2ae3bd701'
      ]
    })
  end

  test 'padding an image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))

    assert_transform(image, {padding: '5'}, {
      geometry: '730x490',
      signature: [
        'e8318730f092dd7edde9b4b2b14a15a7738a8d680c70b1e290caaa9ca7ced73b',
        'e8318730f092dd7edde9b4b2b14a15a7738a8d680c70b1e290caaa9ca7ced73b'
      ]
    })

    assert_transform(image, {padding: '5wF3B902'}, {
      geometry: '730x490',
      signature: [
        'c6285a1d2f14f5b2ac61416d970311a8864ce0d52124cc018f80bf57aec79781',
        'c6285a1d2f14f5b2ac61416d970311a8864ce0d52124cc018f80bf57aec79781'
      ]
    })

    assert_transform(image, {padding: '10,5wF3B902'}, {
      geometry: '730x500',
      signature: [
        '26b8003392505045ce8ea845d50181a80423ee8082a69f32d57653ff1f7459a2',
        '26b8003392505045ce8ea845d50181a80423ee8082a69f32d57653ff1f7459a2'
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
        '833ef40d1a37448a2415b3a101822be14c91039995212dded749a817281c986b',
        '833ef40d1a37448a2415b3a101822be14c91039995212dded749a817281c986b'
      ]
    })
  end
  
  test 'resize an image' do
    image = BobRoss::Image.new(File.open(File.expand_path('../../fixtures/transparent', __FILE__)))

    assert_transform(image, {resize: '100'}, {
      geometry: '100x67',
      signature: [
        'cbf8182cd55943e097b8a6984d88c9dc05bb0712966ce319f2f2e5e2cb18c14b',
        '87279149e22198f1764d4febeaaa50fa2663c9f8294177b8c8a35fbeb4483b97'
      ]
    })

    assert_transform(image, {resize: 'x100'}, {
      geometry: '150x100',
      signature: [
        '3fc278097a41ebfb4aec74f3846a29245ac6242a5dba8adb852b3f6ddd867b3f',
        'c7e70c7b05b97534d691dd4942aa7e9ddd98a794766942eaa24dbb50bf06df44'
      ]
    })

    assert_transform(image, {resize: '100x100'}, {
      geometry: '100x67',
      signature: [
        'cbf8182cd55943e097b8a6984d88c9dc05bb0712966ce319f2f2e5e2cb18c14b',
        '87279149e22198f1764d4febeaaa50fa2663c9f8294177b8c8a35fbeb4483b97'
      ]
    })

    assert_transform(image, {resize: '100x100!'}, {
      geometry: '100x100',
      signature: [
        '03052a757e16147ab78c4a33decc4b944d63f5ddadb95ddff0965139359409e4',
        'a2d43bc3da4d9f37c80c3609563e954b016ac1b87444c1ad0e05c20fbc18b7e8'
      ]
    })

    assert_transform(image, {resize: '1000x1000>'}, {
      geometry: '720x480',
      signature: [
        '573913a44c0df245bfb43766f1c7d41dc079cf17037fb44d27612d18c821bcf6',
        '15c213650c421ce72f62c5bacdd5909fb7d2aad2c172875c647810b50b919d64'
      ]
    })

    assert_transform(image, {resize: '200x200>'}, {
      geometry: '200x133',
      signature: [
        '516be809260dc4bd204762c6c4bc200f8a8f852ebb55f52a8d60632d37ffd42a',
        '1688a3870b2559e879ee4ebdb4c98bf75e9448510ba3d801f6d3574a7287c025'
      ]
    })

    assert_transform(image, {resize: '800x800<'}, {
      geometry: '800x533',
      signature: [
        '5474f686778db5cedabbe270f46034345696e174fc48262b4204776678b981e9',
        '8c3169afe14e5951b37a0721cce325b937d5ad07df6443126f4dbfb4c28bddbf'
      ]
    })

    assert_transform(image, {resize: '200x200<'}, {
      geometry: '720x480',
      signature: [
        '573913a44c0df245bfb43766f1c7d41dc079cf17037fb44d27612d18c821bcf6',
        '15c213650c421ce72f62c5bacdd5909fb7d2aad2c172875c647810b50b919d64'
      ]
    })

    assert_transform(image, {resize: '200x200#p0855AA'}, {
      geometry: '200x200',
      signature: [
        '0def63d52cc868f1a346059503a1f2968ced2ecfb1d6f553ecae44633fa5c399',
        '46f99f9313d290f77880760d684fc886f58d4cbc725af25720842d7fa2c5aaa4'
      ]
    })

    assert_transform(image, {resize: '200x200*'}, {
      geometry: '200x200',
      signature: [
        '1267721debf21c3c7e2e4786f36de538d83b8bbcd12e8079654f068e67c9a6dd',
        'ad4b5a7f8b62e14984af19338f029927b94be6f4a82cb55bf868fd305a19bc58'
      ]
    })

    assert_transform(image, {resize: '200x200*w'}, {
      geometry: '200x200',
      signature: [
        '7c00725a970ff8c8b46fdf733dce6de98502e36b80a5e7454ed5d41a342898c3',
        '0c772ad040c0873e26df3def7a25470209b89a2f85f3f363e48928e663744c6f'
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
        '8c964a0c2e17e043c1dde0d487e107acd972187935296483e894050e3b50e910',
        '98c43cd76fdb5855f6f2b11079dc8ab7817bd7a99fc15c71114428292b5056d7'
      ]
    })

    assert_transform(image, {watermark: '0e'}, {
      geometry: '720x480',
      signature: [
        '80caf3a995d573ff38b8f60f118c274390b7114e8ead1e3804fcba0063af8285',
        'ea28121e80d7d9ea9bfcc0069af0cee75767836ef5ad19aec86d9734862aad21'
      ]
    })

    assert_transform(image, {watermark: '0s'}, {
      geometry: '720x480',
      signature: [
        '7f0d2d94f1184ea6c0876c1bdee88f7eb1c8c7270de998095e7f64a08d143c9c',
        '82117b34d15e0b7ea6c3b85b8d3f1adeb3f435d51bf3cd9a0a1a894f729c3613'
      ]
    })

    assert_transform(image, {watermark: '0w'}, {
      geometry: '720x480',
      signature: [
        'e6a1101d1c0c5412013c4349d4f65ef43c7061b35ae12be52aee3509148a0d8d',
        '33007d3026c4ffa9d471d73ab72bd16d47d275695521d19836dacf2c921cd976'
      ]
    })

    assert_transform(image, {watermark: '0c'}, {
      geometry: '720x480',
      signature: [
        'e67a36e46fe33a4891ac56f004c1af1e0156d3316ce03df2bc32119b3366758a',
        'c7faa72c55030917764d670a020798a602d19d7d5cb60501a4ef5a038e3e1666'
      ]
    })

    assert_transform(image, {watermark: '0ne'}, {
      geometry: '720x480',
      signature: [
        '99833dca62ab3a3b1a1c4d47ffd1ca970c4dd1f3617d94347674d88e54a28274',
        '553d0fb7664bd29a6e660b7bc95e8a8888e0b76d109c0d5773921f54cd2837ee'
      ]
    })

    assert_transform(image, {watermark: '0se'}, {
      geometry: '720x480',
      signature: [
        '5414fec11c784bfd8a72209ce3d85ef3a9ff8f48e17a5d3dc3a31a137c7fdb17',
        'a630e0f0db75c1f8e21247c3db85a1f9e9c7cf549eb243a7239963fc2d7c020a'
      ]
    })

    assert_transform(image, {watermark: '0sw'}, {
      geometry: '720x480',
      signature: [
        '76c12ac5db896f9d7189fb87010c5dfa955d4a3e33a684cb56926565f6062fd5',
        '1acb8ce5d50f38baa0a8ca0f118a8ef53639eda80e6954b2c3ff771824337b23'
      ]
    })

    assert_transform(image, {watermark: '0nw'}, {
      geometry: '720x480',
      signature: [
        'bf3b28f92f52abf840f4d5098bb1c73569505022bf4b3d01f30ee843aa3c298e',
        '6629a15ad67394cced4973f6063300e317868bde0bd5634577863104ed2c8358'
      ]
    })

    assert_transform(image, {watermark: '0o'}, {
      geometry: '720x480',
      signature: [
        '580e1965989ff3c407811410ef70e26e1cea7748335b9cd5b4d17e78768741cf',
        '604c02062b320f5037fb488b62c567106c83e7827b67e998b45d35b6d084469b'
      ]
    })
  end

end