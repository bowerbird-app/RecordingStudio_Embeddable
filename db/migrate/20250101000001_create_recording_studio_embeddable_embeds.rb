# frozen_string_literal: true

class CreateRecordingStudioEmbeddableEmbeds < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_embeddable_embeds, id: :uuid do |t|
      t.string :token, null: false
      t.boolean :enabled, default: false, null: false
      t.string :embed_url_strategy, default: "dedicated", null: false
      t.string :default_embed_mode, default: "iframe", null: false
      t.jsonb :allowed_embed_modes, default: ["iframe"], null: false
      t.jsonb :allowed_embedder_domains, default: [], null: false
      t.jsonb :blocked_embedder_domains, default: [], null: false
      t.boolean :inherit_global_domains, default: true, null: false
      t.boolean :inherit_capability_domains, default: true, null: false
      t.jsonb :sizing, default: {}, null: false
      t.jsonb :appearance, default: {}, null: false
      t.jsonb :security, default: {}, null: false
      t.jsonb :cache_settings, default: {}, null: false
      t.jsonb :logging_settings, default: {}, null: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :recording_studio_embeddable_embeds, :token, unique: true
    add_index :recording_studio_embeddable_embeds, :enabled
    add_index :recording_studio_recordings,
              :parent_recording_id,
              unique: true,
              name: "index_rs_unique_active_embed_per_parent",
              where: active_embed_recording_index_predicate
  end

  private

  def active_embed_recording_index_predicate
    predicate = "recordable_type = 'RecordingStudioEmbeddable::Embed'"
    if column_exists?(:recording_studio_recordings, :trashed_at)
      predicate = "#{predicate} AND trashed_at IS NULL"
    end
    predicate
  end
end
