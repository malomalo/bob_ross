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
    assert_signature(value_for_versions({
      ['>= 4.4.2-0', '< 6.0'] => 'adb611d67ff335ab564e13b4a29daf5f19868588950afd00f2c874bdc92bc0f6',
      ['>= 6.0'] => 'fed332e73ca87a31749b6f27056fc271cc8efd0402315aed0fb7e938b919512a'
    }, ffmpeg_version), image)
  end

  test 'creates a thumbnail for the selected timestamp' do
    image = BobRoss::VideoPlugin.transform(fixture('videos/world.mp4'), {seek: 0})

    assert_geometry('640x360', image)
    assert_signature(value_for_versions({
      ['>= 4.4.2-0', '< 6.0'] => '5ff4311478633fb23f44ff1d6d16286baafb885531a86ddb2c7ccaf22fe4f52f',
      ['>= 6.0'] => '1d3e16995c5dfadf73f67a5695c02f14b1cbae07ca168aaf79c9f0d728db44c8'
    }, ffmpeg_version), image)
  end

  test 'creates a thumbnail for the selected percentage of movie' do
    image = BobRoss::VideoPlugin.transform(fixture('videos/world.mp4'), {seek: '100%'})

    assert_geometry('640x360', image)
    assert_signature(value_for_versions({
      ['>= 4.4.2-0', '< 6.0'] => 'd1e07b1a1d504b30a6e6f01281bb647fab67a5b23b2ca369ca946531f85eff69',
      ['>= 6.0'] => '74c9aaaedbd064a5bbb71c65df3e42f9c56e4146ac5830147619cec39adbf8e9'
    }, ffmpeg_version), image)
  end

end