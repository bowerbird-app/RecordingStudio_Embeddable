# frozen_string_literal: true

require "test_helper"

# Core's apply_capabilities! includes RecordingMethods on every to_prepare from
# register_capability(:embeddable). This engine must not re-include it.
class RecordingMethodsBootTest < ActiveSupport::TestCase
  test "recordings include embeddable methods at boot and after reload" do
    assert_includes RecordingStudio::Recording.included_modules, RecordingStudioEmbeddable::RecordingMethods

    # Test caches classes. Metrics treats to_prepare as a fresh registration unless
    # cache_classes is false, which is how development reload works.
    Rails.application.config.cache_classes = false
    Rails.application.reloader.reload!

    assert_includes RecordingStudio::Recording.included_modules, RecordingStudioEmbeddable::RecordingMethods

    actor = User.create!(
      email: "boot-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = actor
    workspace = Workspace.create!(name: "Boot #{SecureRandom.hex(4)}")
    page = RecordingStudio.root_recording_for(workspace).record(Page, actor: actor) do |record|
      record.title = "Boot page"
    end

    assert_respond_to page, :embed
  ensure
    Rails.application.config.cache_classes = true
    Current.actor = nil
  end
end
