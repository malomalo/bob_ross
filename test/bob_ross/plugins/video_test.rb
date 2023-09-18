require 'test_helper'

class VideoPluginTest < Minitest::Test

  test 'extract_transformations' do
    # No transformations
    transformations = BobRoss::VideoPlugin.extract_transformations('')
    assert_equal [], transformations

    # No transformations for plugin
    transformation_string = 'G'
    transformations = BobRoss::VideoPlugin.extract_transformations(transformation_string)
    assert_equal [], transformations
    assert_equal 'G', transformation_string

    # Just transformations for plugin
    transformation_string = 'F1'
    transformations = BobRoss::VideoPlugin.extract_transformations(transformation_string)
    assert_equal [{seek: '1'}], transformations
    assert_equal '', transformation_string

    # transformations for both plugin and BobRoss
    transformation_string = 'F1G'
    transformations = BobRoss::VideoPlugin.extract_transformations(transformation_string)
    assert_equal [{seek: '1'}], transformations
    assert_equal 'G', transformation_string

    # malformed options are skipped
    transformation_string = 'F1@G'
    transformations = BobRoss::VideoPlugin.extract_transformations(transformation_string)
    assert_equal [], transformations
    assert_equal 'F1@G', transformation_string
  end

  test 'creates a thumbnail for the video with video dimensions' do
    image = BobRoss::VideoPlugin.transform(fixture('videos/world.mp4'))

    assert_geometry('640x360', image)
    assert_signature(
      'fed332e73ca87a31749b6f27056fc271cc8efd0402315aed0fb7e938b919512a',
      image
    )
  end

  test 'creates a thumbnail for the selected timestamp' do
    image = BobRoss::VideoPlugin.transform(fixture('videos/world.mp4'), {seek: 0})

    assert_geometry('640x360', image)
    assert_signature(
      '1d3e16995c5dfadf73f67a5695c02f14b1cbae07ca168aaf79c9f0d728db44c8',
      image
    )
  end

  test 'creates a thumbnail for the selected percentage of movie' do
    image = BobRoss::VideoPlugin.transform(fixture('videos/world.mp4'), {seek: '100%'})

    assert_geometry('640x360', image)
    assert_signature(
      '74c9aaaedbd064a5bbb71c65df3e42f9c56e4146ac5830147619cec39adbf8e9',
      image
    )
  end

end