# frozen_string_literal: true

class CreateRecordingStudioEmbeddableStylingProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_embeddable_styling_profiles, id: :uuid do |t|
      t.string :recordable_type, null: false
      t.jsonb :defaults, null: false, default: {}
      t.boolean :allow_custom_styling, null: false, default: true
      t.integer :version, null: false, default: 0

      t.timestamps
    end

    add_index :recording_studio_embeddable_styling_profiles,
              :recordable_type,
              unique: true,
              name: "idx_rse_styling_profiles_recordable_type"
  end
end