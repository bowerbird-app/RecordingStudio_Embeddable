# frozen_string_literal: true

require "test_helper"

class TrashableActiveScopeParityTest < Minitest::Test
  class BaseFakeRecordingRelation
    attr_reader :calls

    def initialize(rows)
      @rows = rows
      @calls = []
      @filters = {}
    end

    def where(**attrs)
      @calls << [:where, attrs]
      dup_with(filters: @filters.merge(attrs))
    end

    def first
      @rows.find { |row| @filters.all? { |key, value| row[key] == value } }
    end

    private

    def dup_with(filters:)
      copy = self.class.new(@rows)
      copy.instance_variable_set(:@calls, @calls)
      copy.instance_variable_set(:@filters, filters)
      copy
    end
  end

  class TrashableAwareRecordingRelation < BaseFakeRecordingRelation
    def recording_studio_trashable_active
      @calls << :recording_studio_trashable_active
      dup_with(filters: @filters.merge(trashed_at: nil))
    end
  end

  class LegacyRecordingRelation < BaseFakeRecordingRelation
  end

  class HostRecording
    include RecordingStudioEmbeddable::RecordingMethods

    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  def setup
    @had_recording = defined?(RecordingStudio::Recording)
    @previous_recording = RecordingStudio::Recording if @had_recording
  end

  def teardown
    return unless defined?(RecordingStudio)

    RecordingStudio.send(:remove_const, :Recording) if RecordingStudio.const_defined?(:Recording)
    RecordingStudio.const_set(:Recording, @previous_recording) if @had_recording
  end

  def test_embed_child_recording_prefers_trashable_active_over_hash_filter
    relation = TrashableAwareRecordingRelation.new(rows_for("parent-1"))
    replace_recording_const(relation)

    child = HostRecording.new("parent-1").embed_child_recording

    assert_includes relation.calls, :recording_studio_trashable_active
    assert(relation.calls.any? do |call|
      call == [:where, { parent_recording_id: "parent-1",
                         recordable_type: "RecordingStudioEmbeddable::Embed" }]
    end)
    refute(relation.calls.any? { |call| call.is_a?(Array) && call.last.key?(:trashed_at) })
    assert_equal "kept-child", child[:id]
  end

  def test_embed_child_recording_falls_back_to_trashed_at_nil_without_trashable_scope
    relation = LegacyRecordingRelation.new(rows_for("parent-2"))
    replace_recording_const(relation)
    refute relation.respond_to?(:recording_studio_trashable_active)

    child = HostRecording.new("parent-2").embed_child_recording

    assert_equal [:where, { trashed_at: nil }], relation.calls.first
    assert_equal "kept-child", child[:id]
  end

  private

  def rows_for(parent_id, embed_id: "embed-1")
    kept = {
      parent_recording_id: parent_id,
      recordable_type: "RecordingStudioEmbeddable::Embed",
      recordable_id: embed_id,
      trashed_at: nil,
      id: "kept-child"
    }
    trashed = kept.merge(
      id: "trashed-child",
      trashed_at: Time.utc(2026, 10, 13)
    )
    [kept, trashed]
  end

  def replace_recording_const(relation)
    RecordingStudio.send(:remove_const, :Recording) if RecordingStudio.const_defined?(:Recording)
    RecordingStudio.const_set(:Recording, relation)
  end
end
