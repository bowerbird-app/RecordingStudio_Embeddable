# frozen_string_literal: true

class Widget < ApplicationRecord
  recording_studio_recordable label: "Widget", root: false, allowed_parent_types: ["Workspace", "Folder"]

  include RecordingStudio::Capabilities::Embeddable.to(
    embed_controller: "widgets",
    embed_action: :embed,
    require_publishable: false,
    floating: true,
    floating_popup: { controller: "widget_popups", action: :show },
    floating_options: {
      edge_spacing: 24,
      popup_width: 400,
      popup_height: 640
    },
    customizable_embed_styles: {
      background_color: {
        label: "Background color",
        css_variable: "--surface-background-color",
        input: :color,
        default: "#ffffff"
      },
      text_color: {
        label: "Text color",
        css_variable: "--surface-content-color",
        input: :color,
        default: "#0f172a"
      },
      accent_color: {
        label: "Accent color",
        css_variable: "--color-primary",
        input: :color,
        default: "#111827"
      },
      accent_text_color: {
        label: "Accent text color",
        css_variable: "--color-primary-text",
        input: :color,
        default: "#ffffff"
      }
    }
  )

  def self.recordable_type_label
    "Widget"
  end

  class << self
    alias_method :recording_studio_type_label, :recordable_type_label
  end

  def recordable_name
    title.to_s.squish.presence || self.class.recordable_type_label
  end

  alias_method :recording_studio_label, :recordable_name
end
