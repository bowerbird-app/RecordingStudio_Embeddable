# frozen_string_literal: true

require "test_helper"

class RootSwitchablePinTest < ActiveSupport::TestCase
  test "dummy pins the wave 5 Recording Studio ladder" do
    assert_equal "7.3.0", RecordingStudio::VERSION
    assert_equal "0.16.0", RecordingStudioRootSwitchable::VERSION
    assert_equal "0.9.0", RecordingStudioMetrics::VERSION
    assert_equal "0.45.1", RecordingStudioAccessible::VERSION
    assert_equal "2.18.0", RecordingStudioAdmin::VERSION
    assert_equal "1.2.1", RecordingStudioApi::VERSION
    assert_equal "6.0.0", RecordingStudioMoveable::VERSION
    assert_equal "0.4.0", RecordingStudioIcons::VERSION
    assert_equal "0.1.377", FlatPack::VERSION
    assert_equal "0.5.0", RecordingStudioArtifacts::VERSION
    assert_equal "0.31.0", RecordingStudioAttachable::VERSION
    assert_equal "0.7.0", RecordingStudioCache::VERSION
    assert_equal "0.8.0", RecordingStudioLogs::VERSION
    assert_equal "1.1.0", RecordingStudioPublishable::VERSION
    assert_equal "1.0.1", RecordingStudioTrashable::VERSION

    authorizer = RecordingStudio.configuration.authorize_write
    assert authorizer.call(actor: Object.new)
    refute authorizer.call(actor: nil)
  end

  test "mounted page authorizer allows a Studio Workspace root admin" do
    user = User.create!(
      email: "studio-admin-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    outsider = User.create!(
      email: "studio-outsider-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
    root = RecordingStudio.create_root_recording!(workspace, actor: user)
    refute RecordingStudioAccessible.configuration.authorize_mounted_page?(
      controller: nil,
      actor: user,
      recording: nil
    )

    bootstrap = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: user)
    assert bootstrap.success?, bootstrap.error.to_s

    assert_equal root, RecordingStudioAccessible.configuration.admin_root_resolver.call
    assert RecordingStudioAccessible.configuration.authorize_mounted_page?(
      controller: nil,
      actor: user,
      recording: nil
    )
    refute RecordingStudioAccessible.configuration.authorize_mounted_page?(
      controller: nil,
      actor: outsider,
      recording: nil
    )
  end

  test "default page_copy boots with English defaults" do
    copy = RecordingStudioRootSwitchable.configuration.page_copy

    assert_equal "Switch", copy.fetch(:title)
    assert_equal "Switch", copy.fetch(:switch_action_label)
    assert_equal "", copy.fetch(:subtitle)
    assert_equal "", copy.fetch(:persistence_hint)
  end
end
