# frozen_string_literal: true

class RenameRecordingStudioEmbeddableViewsToEmbeddableViewLogs < ActiveRecord::Migration[8.1]
  OLD_TABLE = :recording_studio_embeddable_views
  NEW_TABLE = :recording_studio_embeddable_embeddable_view_logs

  INDEX_RENAMES = {
    "idx_rse_views_viewed_at" => "idx_rse_view_logs_viewed_at",
    "idx_rse_views_embed_viewed_at" => "idx_rse_view_logs_embed_viewed_at",
    "idx_rse_views_parent_recording_viewed_at" => "idx_rse_view_logs_parent_recording_viewed_at",
    "idx_rse_views_status_viewed_at" => "idx_rse_view_logs_status_viewed_at",
    "idx_rse_views_token_viewed_at" => "idx_rse_view_logs_token_viewed_at",
    "idx_rse_views_referer_viewed_at" => "idx_rse_view_logs_referer_viewed_at",
    "idx_rse_views_viewer_viewed_at" => "idx_rse_view_logs_viewer_viewed_at",
    "idx_rse_views_bot" => "idx_rse_view_logs_bot",
    "index_recording_studio_embeddable_views_on_embed_id" => "index_recording_studio_embeddable_embeddable_view_logs_on_embed_id"
  }.freeze

  def up
    return unless table_exists?(OLD_TABLE)

    rename_table OLD_TABLE, NEW_TABLE
    rename_indexes(NEW_TABLE, INDEX_RENAMES)
  end

  def down
    return unless table_exists?(NEW_TABLE)

    rename_indexes(NEW_TABLE, INDEX_RENAMES.invert)
    rename_table NEW_TABLE, OLD_TABLE
  end

  private

  def rename_indexes(table, mapping)
    mapping.each do |old_name, new_name|
      next unless index_name_exists?(table, old_name)
      next if index_name_exists?(table, new_name)

      rename_index table, old_name, new_name
    end
  end
end
