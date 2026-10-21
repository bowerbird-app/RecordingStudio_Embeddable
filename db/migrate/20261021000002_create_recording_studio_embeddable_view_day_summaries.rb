# frozen_string_literal: true

class CreateRecordingStudioEmbeddableViewDaySummaries < ActiveRecord::Migration[8.1]
  TABLE = "recording_studio_embeddable_view_day_summaries"

  def up
    RecordingStudioLogs::Schema.install_runs!(connection)

    return if connection.data_source_exists?(TABLE)

    create_table TABLE, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.date :day, null: false
      t.uuid :root_recording_id
      t.uuid :embed_id
      t.uuid :parent_recording_id
      t.string :status, null: false
      t.bigint :view_count, null: false, default: 0
      t.timestamps
    end
    RecordingStudioLogs::Schema.summary_index(
      TABLE,
      %i[day root_recording_id embed_id parent_recording_id status],
      name: "index_rse_view_day_summaries_identity"
    )
    add_index TABLE, %i[root_recording_id day], name: "idx_rse_view_day_summaries_root_day"
    add_index TABLE, %i[embed_id day], name: "idx_rse_view_day_summaries_embed_day"
  end

  def down
    drop_table TABLE if connection.data_source_exists?(TABLE)
  end
end
