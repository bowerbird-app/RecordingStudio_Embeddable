# frozen_string_literal: true

class AddFloatingToRecordingStudioEmbeddableEmbeds < ActiveRecord::Migration[8.1]
  def change
    change_table :recording_studio_embeddable_embeds, bulk: true do |t|
      t.boolean :floating_enabled, default: false, null: false
      t.jsonb :floating, default: {}, null: false
    end
  end
end
