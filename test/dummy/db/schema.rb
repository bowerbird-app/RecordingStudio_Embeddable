# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_01_010002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "articles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "documents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "folders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "pages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "recording_studio_access_boundaries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "minimum_role"
  end

  create_table "recording_studio_accesses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "actor_id", null: false
    t.string "actor_type", null: false
    t.datetime "created_at", null: false
    t.integer "role", default: 0, null: false
    t.index ["actor_type", "actor_id", "role"], name: "index_recording_studio_accesses_on_actor_and_role"
    t.index ["actor_type", "actor_id"], name: "index_recording_studio_accesses_on_actor"
  end

  create_table "recording_studio_device_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "actor_id", null: false
    t.string "actor_type", null: false
    t.datetime "created_at", null: false
    t.string "device_fingerprint", null: false
    t.string "device_name"
    t.datetime "last_active_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.uuid "root_recording_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["actor_type", "actor_id", "device_fingerprint"], name: "index_rs_device_sessions_on_actor_and_fingerprint", unique: true
    t.index ["root_recording_id"], name: "index_rs_device_sessions_on_root_recording"
  end

  create_table "recording_studio_embeddable_embeds", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "allowed_embed_modes", default: ["iframe"], null: false
    t.jsonb "allowed_embedder_domains", default: [], null: false
    t.jsonb "appearance", default: {}, null: false
    t.jsonb "blocked_embedder_domains", default: [], null: false
    t.jsonb "cache_settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "default_embed_mode", default: "iframe", null: false
    t.string "embed_url_strategy", default: "dedicated", null: false
    t.boolean "enabled", default: false, null: false
    t.boolean "inherit_capability_domains", default: true, null: false
    t.boolean "inherit_global_domains", default: true, null: false
    t.jsonb "logging_settings", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.jsonb "security", default: {}, null: false
    t.jsonb "sizing", default: {}, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_recording_studio_embeddable_embeds_on_enabled"
    t.index ["token"], name: "index_recording_studio_embeddable_embeds_on_token", unique: true
  end

  create_table "recording_studio_embeddable_views", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "bot", default: false, null: false
    t.boolean "cache_hit", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.uuid "embed_id"
    t.string "embed_mode"
    t.uuid "embed_recording_id"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "parent_recordable_id"
    t.string "parent_recordable_type"
    t.uuid "parent_recording_id"
    t.boolean "rate_limited", default: false, null: false
    t.text "referer"
    t.string "referer_digest"
    t.string "referer_host"
    t.string "remote_ip"
    t.string "remote_ip_digest"
    t.string "request_host"
    t.string "request_method"
    t.string "request_path"
    t.string "status", default: "rendered", null: false
    t.integer "status_code"
    t.string "token_digest"
    t.datetime "updated_at", null: false
    t.string "url_strategy"
    t.text "user_agent"
    t.string "user_agent_digest"
    t.datetime "viewed_at", null: false
    t.string "viewer_digest"
    t.index ["bot"], name: "idx_rse_views_bot"
    t.index ["embed_id", "viewed_at"], name: "idx_rse_views_embed_viewed_at"
    t.index ["embed_id"], name: "index_recording_studio_embeddable_views_on_embed_id"
    t.index ["parent_recording_id", "viewed_at"], name: "idx_rse_views_parent_recording_viewed_at"
    t.index ["referer_host", "viewed_at"], name: "idx_rse_views_referer_viewed_at"
    t.index ["status", "viewed_at"], name: "idx_rse_views_status_viewed_at"
    t.index ["token_digest", "viewed_at"], name: "idx_rse_views_token_viewed_at"
    t.index ["viewed_at"], name: "idx_rse_views_viewed_at"
    t.index ["viewer_digest", "viewed_at"], name: "idx_rse_views_viewer_viewed_at"
  end

  create_table "recording_studio_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "actor_id"
    t.string "actor_type"
    t.datetime "created_at", null: false
    t.string "idempotency_key"
    t.uuid "impersonator_id"
    t.string "impersonator_type"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.uuid "previous_recordable_id"
    t.string "previous_recordable_type"
    t.uuid "recordable_id", null: false
    t.string "recordable_type", null: false
    t.uuid "recording_id", null: false
    t.index ["recording_id", "idempotency_key"], name: "index_recording_studio_events_on_recording_and_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["recording_id"], name: "index_recording_studio_events_on_recording_id"
  end

  create_table "recording_studio_publishable_publishables", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "canonical_url"
    t.datetime "created_at", null: false
    t.string "meta_robots"
    t.datetime "publish_at"
    t.text "seo_description"
    t.string "seo_title"
    t.string "slug", null: false
    t.text "social_description"
    t.uuid "social_image_attachment_recording_id"
    t.string "social_title"
    t.string "status", default: "draft", null: false
    t.string "time_zone"
    t.datetime "unpublish_at"
    t.datetime "updated_at", null: false
    t.index ["canonical_url"], name: "index_rs_publishables_on_canonical_url"
    t.index ["slug"], name: "index_rs_publishables_on_slug"
    t.index ["social_image_attachment_recording_id"], name: "index_rs_publishables_on_social_image_attachment_recording_id"
    t.index ["status", "publish_at", "unpublish_at"], name: "index_publishables_on_status_and_publish_times"
    t.index ["status", "publish_at", "unpublish_at"], name: "index_rs_publishables_on_state_window"
  end

  create_table "recording_studio_recordings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "parent_recording_id"
    t.uuid "recordable_id", null: false
    t.string "recordable_type", null: false
    t.uuid "root_recording_id"
    t.datetime "trashed_at"
    t.datetime "updated_at", null: false
    t.index ["parent_recording_id"], name: "index_recording_studio_recordings_on_parent_recording_id"
    t.index ["parent_recording_id"], name: "index_rs_publishable_child_per_parent", unique: true, where: "(((recordable_type)::text = 'RecordingStudioPublishable::Publishable'::text) AND (trashed_at IS NULL))"
    t.index ["parent_recording_id"], name: "index_rs_unique_active_access_boundary_per_parent", unique: true, where: "(((recordable_type)::text = 'RecordingStudio::AccessBoundary'::text) AND (trashed_at IS NULL))"
    t.index ["parent_recording_id"], name: "index_rs_unique_active_embed_per_parent", unique: true, where: "(((recordable_type)::text = 'RecordingStudioEmbeddable::Embed'::text) AND (trashed_at IS NULL))"
    t.index ["recordable_id", "root_recording_id"], name: "idx_rs_recordings_root_access", where: "(((recordable_type)::text = 'RecordingStudio::Access'::text) AND (parent_recording_id IS NOT NULL) AND (trashed_at IS NULL))"
    t.index ["recordable_type", "recordable_id", "parent_recording_id", "trashed_at"], name: "index_recording_studio_recordings_on_recordable_parent_trashed"
    t.index ["recordable_type", "recordable_id"], name: "index_recording_studio_recordings_on_recordable"
    t.index ["root_recording_id"], name: "index_rs_recordings_on_root_recording"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "workspaces", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "recording_studio_device_sessions", "recording_studio_recordings", column: "root_recording_id"
  add_foreign_key "recording_studio_embeddable_views", "recording_studio_embeddable_embeds", column: "embed_id"
  add_foreign_key "recording_studio_events", "recording_studio_recordings", column: "recording_id"
  add_foreign_key "recording_studio_publishable_publishables", "recording_studio_recordings", column: "social_image_attachment_recording_id", name: "fk_rs_publishables_social_image_attachment_recording"
  add_foreign_key "recording_studio_recordings", "recording_studio_recordings", column: "parent_recording_id"
  add_foreign_key "recording_studio_recordings", "recording_studio_recordings", column: "root_recording_id"
end
