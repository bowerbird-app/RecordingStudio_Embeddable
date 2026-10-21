# frozen_string_literal: true

class AddRootAndArrivalToRecordingStudioEmbeddableViewLogs < ActiveRecord::Migration[8.1]
  TABLE = :recording_studio_embeddable_view_logs
  ROOT_INDEX = "idx_rse_view_logs_root_viewed_at"

  def up
    return unless table_exists?(TABLE)

    add_column TABLE, :root_recording_id, :uuid unless column_exists?(TABLE, :root_recording_id)
    add_column TABLE, :arrived_at, :datetime unless column_exists?(TABLE, :arrived_at)

    backfill_root_recording_ids
    backfill_arrived_at

    change_column_default TABLE, :arrived_at, from: nil, to: -> { "CURRENT_TIMESTAMP" }
    change_column_null TABLE, :arrived_at, false if column_exists?(TABLE, :arrived_at)

    return if index_exists?(TABLE, %i[root_recording_id viewed_at], name: ROOT_INDEX)

    add_index TABLE, %i[root_recording_id viewed_at], name: ROOT_INDEX
  end

  def down
    return unless table_exists?(TABLE)

    remove_index TABLE, name: ROOT_INDEX if index_exists?(TABLE, %i[root_recording_id viewed_at], name: ROOT_INDEX)
    remove_column TABLE, :arrived_at if column_exists?(TABLE, :arrived_at)
    remove_column TABLE, :root_recording_id if column_exists?(TABLE, :root_recording_id)
  end

  private

  def backfill_root_recording_ids
    return unless table_exists?(:recording_studio_recordings)

    execute <<~SQL.squish
      UPDATE #{TABLE} AS logs
      SET root_recording_id = COALESCE(recordings.root_recording_id, recordings.id)
      FROM recording_studio_recordings AS recordings
      WHERE logs.root_recording_id IS NULL
        AND recordings.id = logs.parent_recording_id
    SQL

    execute <<~SQL.squish
      UPDATE #{TABLE} AS logs
      SET root_recording_id = COALESCE(recordings.root_recording_id, recordings.id)
      FROM recording_studio_recordings AS recordings
      WHERE logs.root_recording_id IS NULL
        AND recordings.id = logs.embed_recording_id
    SQL
  end

  def backfill_arrived_at
    execute <<~SQL.squish
      UPDATE #{TABLE}
      SET arrived_at = COALESCE(arrived_at, created_at, viewed_at)
      WHERE arrived_at IS NULL
    SQL
  end
end
