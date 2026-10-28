# frozen_string_literal: true

require "test_helper"

class RootSwitchablePinTest < ActiveSupport::TestCase
  test "dummy pins root_switchable 0.11.0 and metrics 0.7.0" do
    assert_equal "0.11.0", RecordingStudioRootSwitchable::VERSION
    assert_equal "0.7.0", RecordingStudioMetrics::VERSION
  end

  test "default page_copy boots with English defaults" do
    copy = RecordingStudioRootSwitchable.configuration.page_copy

    assert_equal "Switch", copy.fetch(:title)
    assert_equal "Switch", copy.fetch(:switch_action_label)
    assert_equal "", copy.fetch(:subtitle)
    assert_equal "", copy.fetch(:persistence_hint)
  end
end
