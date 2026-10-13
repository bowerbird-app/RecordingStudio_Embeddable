# frozen_string_literal: true

require "test_helper"

class TrashableEmbedLookupParityTest < ActiveSupport::TestCase
  setup do
    RecordingStudioTrashable.install_recording_capabilities!
    @previous_default_scopes = RecordingStudio::Recording.default_scopes.dup
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
    RecordingStudio::Recording.default_scopes.replace(@previous_default_scopes)
    Current.actor = nil
  end

  test "kept_sql WHERE matches main trashed_at nil results on the same base relation" do
    base = RecordingStudio::Recording.where(
      parent_recording_id: @page_recording.id,
      recordable_type: "RecordingStudioEmbeddable::Embed"
    )
    main_ids = base.where(trashed_at: nil).pluck(:id)
    kept_sql_ids = base.where(RecordingStudio::Recording.recording_studio_trashable_kept_sql).pluck(:id)

    assert_equal main_ids, kept_sql_ids
    assert_equal [ @embed_recording.id ], main_ids
    # AR wraps string WHERE fragments in parentheses; hash form does not — same predicate.
    assert_includes base.where(RecordingStudio::Recording.recording_studio_trashable_kept_sql).to_sql,
                    RecordingStudio::Recording.recording_studio_trashable_kept_sql
    assert_equal(
      %("child"."trashed_at" IS NULL),
      RecordingStudio::Recording.recording_studio_trashable_kept_sql("child")
    )
  end

  test "embed lookups match main under a trashed_at default_scope and diverge from active" do
    # Host default_scope that only exposes trashed rows. Main's additive
    # where(trashed_at: nil) contradicts it and returns none; active unscopes
    # first and would still find the kept embed child.
    RecordingStudio::Recording.send(:default_scope, -> { where.not(trashed_at: nil) })

    main_ids = RecordingStudio::Recording.where(
      parent_recording_id: @page_recording.id,
      recordable_type: "RecordingStudioEmbeddable::Embed",
      trashed_at: nil
    ).pluck(:id)
    kept_sql_ids = RecordingStudio::Recording.where(
      parent_recording_id: @page_recording.id,
      recordable_type: "RecordingStudioEmbeddable::Embed"
    ).where(RecordingStudio::Recording.recording_studio_trashable_kept_sql).pluck(:id)
    active_ids = RecordingStudio::Recording.recording_studio_trashable_active.where(
      parent_recording_id: @page_recording.id,
      recordable_type: "RecordingStudioEmbeddable::Embed"
    ).pluck(:id)

    assert_equal main_ids, kept_sql_ids
    assert_empty main_ids
    assert_includes active_ids, @embed_recording.id,
                    "active scope unscopes default_scope and must not be used for embed lookups"

    # Do not reload @page_recording — a kept parent is invisible under this default_scope.
    assert_nil @page_recording.embed_child_recording
    assert_nil @page_recording.embed
    assert_nil @embed.recording
  end

  test "embed lookups still find kept children under a kept-only default_scope" do
    RecordingStudio::Recording.send(:default_scope, -> { where(trashed_at: nil) })

    main = RecordingStudio::Recording.where(
      parent_recording_id: @page_recording.id,
      recordable_type: "RecordingStudioEmbeddable::Embed",
      trashed_at: nil
    ).first
    via_lookup = @page_recording.embed_child_recording

    assert_equal main.id, via_lookup.id
    assert_equal @embed.id, @page_recording.embed.id
    assert_equal @embed_recording.id, @embed.recording.id
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
