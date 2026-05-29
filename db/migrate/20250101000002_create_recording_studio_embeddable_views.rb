# frozen_string_literal: true

class CreateRecordingStudioEmbeddableViews < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_embeddable_views, id: :uuid do |t|
      t.references :embed, type: :uuid, null: true, foreign_key: { to_table: :recording_studio_embeddable_embeds }
      t.uuid :embed_recording_id
      t.uuid :parent_recording_id
      t.string :parent_recordable_type
      t.uuid :parent_recordable_id
      t.string :token_digest
      t.string :embed_mode
      t.string :url_strategy
      t.string :request_host
      t.string :request_path
      t.string :request_method
      t.string :remote_ip_digest
      t.string :user_agent_digest
      t.string :viewer_digest
      t.string :referer_host
      t.string :referer_digest
      t.string :remote_ip
      t.text :user_agent
      t.text :referer
      t.string :status, null: false, default: "rendered"
      t.integer :status_code
      t.boolean :cache_hit, default: false, null: false
      t.boolean :rate_limited, default: false, null: false
      t.integer :duration_ms
      t.jsonb :metadata, default: {}, null: false
      t.boolean :bot, default: false, null: false
      t.datetime :viewed_at, null: false

      t.timestamps
    end

    add_index :recording_studio_embeddable_views, :viewed_at
    add_index :recording_studio_embeddable_views, %i[embed_id viewed_at]
    add_index :recording_studio_embeddable_views, %i[parent_recording_id viewed_at]
    add_index :recording_studio_embeddable_views, %i[status viewed_at]
    add_index :recording_studio_embeddable_views, %i[token_digest viewed_at]
    add_index :recording_studio_embeddable_views, %i[referer_host viewed_at]
    add_index :recording_studio_embeddable_views, %i[viewer_digest viewed_at]
    add_index :recording_studio_embeddable_views, :bot
  end
end
