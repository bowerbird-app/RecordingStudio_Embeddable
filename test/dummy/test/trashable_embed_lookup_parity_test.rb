# frozen_string_literal: true

require "test_helper"

class TrashableEmbedLookupParityTest < ActiveSupport::TestCase
  setup do
    RecordingStudioTrashable.install_recording_capabilities!
    @user = User.create!(
      email: "trashable-embed-#{SecureRandom.hex(4)}@example.com",
      password: "EmbedProofPassword!2026",
      password_confirmation: "EmbedProofPassword!2026"
    )
    Current.actor = @user
    workspace = Workspace.create!(name: "Trashable embed #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(workspace)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @user)
    @page_recording = @root.record(Page, actor: @user) do |page|
      page.title = "Trashable embed page"
    end
    @embed = @page_recording.ensure_embed!(enabled: true, allowed_embedder_domains: [ "example.com" ])
    @embed_recording = @page_recording.embed_child_recording
  end

  teardown do
    Current.actor = nil
  end

  test "active scope SQL matches main unscope-plus-trashed_at-nil filter" do
    active_sql = RecordingStudio::Recording.recording_studio_trashable_active.to_sql
    legacy_sql = RecordingStudio::Recording.unscope(where: :trashed_at).where(trashed_at: nil).to_sql

    assert_equal legacy_sql, active_sql
  end

  test "kept and trashed SQL helpers quote table aliases like trashable docs" do
    assert_equal(
      %("#{RecordingStudio::Recording.table_name}"."trashed_at" IS NULL),
      RecordingStudio::Recording.recording_studio_trashable_kept_sql
    )
    assert_equal(
      %("child"."trashed_at" IS NULL),
      RecordingStudio::Recording.recording_studio_trashable_kept_sql("child")
    )
    assert_equal(
      %("child"."trashed_at" IS NOT NULL),
      RecordingStudio::Recording.recording_studio_trashable_trashed_sql("child")
    )
  end

  test "embed_child_recording and Embed#recording hide soft-voided rows" do
    assert_equal @embed.id, @page_recording.embed.id
    assert_equal @embed_recording.id, @embed.recording.id
    assert @embed_recording.recording_studio_trashable_kept?
    refute @embed_recording.recording_studio_trashable_trashed?

    time = Time.utc(2026, 10, 13, 12, 0, 0)
    result = RecordingStudioTrashable.void_recording!(@embed_recording, time: time)

    assert_equal @embed_recording, result
    @embed_recording.reload
    assert @embed_recording.recording_studio_trashable_trashed?
    assert_equal time, @embed_recording.trashed_at
    assert_nil @page_recording.reload.embed
    assert_nil @page_recording.embed_child_recording
    assert_nil @embed.recording
    assert_empty(
      RecordingStudio::Recording.recording_studio_trashable_active.where(id: @embed_recording.id)
    )
  end

  test "void_recording! is idempotent and uses update_columns semantics" do
    time = Time.utc(2026, 10, 13, 13, 0, 0)
    RecordingStudioTrashable.void_recording!(@embed_recording, time: time)
    first_trashed_at = @embed_recording.reload.trashed_at

    RecordingStudioTrashable.void_recording!(@embed_recording, time: Time.utc(2026, 10, 14))
    assert_equal first_trashed_at, @embed_recording.reload.trashed_at
  end

  test "restoring trashed_at makes embed lookups return the child again" do
    RecordingStudioTrashable.void_recording!(@embed_recording, time: Time.utc(2026, 10, 13))
    assert_nil @page_recording.reload.embed

    @embed_recording.update_columns(trashed_at: nil, updated_at: Time.current)
    assert_equal @embed.id, @page_recording.reload.embed.id
    assert_equal @embed_recording.id, @embed.recording.id
  end
end
