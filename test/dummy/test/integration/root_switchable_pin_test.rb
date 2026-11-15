# frozen_string_literal: true

require "test_helper"

class RootSwitchablePinTest < ActiveSupport::TestCase
  test "dummy pins the wave 5 Recording Studio ladder" do
    assert_equal "7.0.0", RecordingStudio::VERSION
    assert_equal "0.16.0", RecordingStudioRootSwitchable::VERSION
    assert_equal "0.9.0", RecordingStudioMetrics::VERSION
    assert_equal "0.44.0", RecordingStudioAccessible::VERSION
    assert_equal "2.16.0", RecordingStudioAdmin::VERSION
    assert_equal "0.24.0", RecordingStudioApi::VERSION
    assert_equal "5.0.0", RecordingStudioMoveable::VERSION
    assert_equal "0.2.1", RecordingStudioIcons::VERSION
    assert_equal "0.1.376", FlatPack::VERSION

    authorizer = RecordingStudio.configuration.authorize_write
    assert authorizer.call(actor: Object.new)
    refute authorizer.call(actor: nil)
  end

  test "default page_copy boots with English defaults" do
    copy = RecordingStudioRootSwitchable.configuration.page_copy

    assert_equal "Switch", copy.fetch(:title)
    assert_equal "Switch", copy.fetch(:switch_action_label)
    assert_equal "", copy.fetch(:subtitle)
    assert_equal "", copy.fetch(:persistence_hint)
  end
end
