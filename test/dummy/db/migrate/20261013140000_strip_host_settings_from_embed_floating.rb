# frozen_string_literal: true

class StripHostSettingsFromEmbedFloating < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE recording_studio_embeddable_embeds
      SET floating = floating
        - 'edge_spacing'
        - 'popup_width'
        - 'popup_height'
        - 'icon_url'
    SQL
  end

  def down
    # Host settings are not stored on the embed. Nothing to restore.
  end
end
