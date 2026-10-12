# frozen_string_literal: true

require "test_helper"

# Dummy pins RootSwitchable for Admin API HTML (current_root_recording).
# 0.7+ also pulls recording_studio_metrics; 0.8.0 validates page_copy at boot.
class RootSwitchablePinTest < ActiveSupport::TestCase
  test "dummy pins root_switchable 0.8.0 and metrics 0.2.0" do
    assert_equal "0.8.0", RecordingStudioRootSwitchable::VERSION
    assert_equal "0.2.0", RecordingStudioMetrics::VERSION
  end

  test "default page_copy boots with English defaults" do
    copy = RecordingStudioRootSwitchable.configuration.page_copy

    assert_equal "Switch", copy.fetch(:title)
    assert_equal "Switch", copy.fetch(:switch_action_label)
    assert_equal "", copy.fetch(:subtitle)
    assert_equal "", copy.fetch(:persistence_hint)
  end
end
