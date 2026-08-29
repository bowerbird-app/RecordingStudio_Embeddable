class Article < ApplicationRecord
  recording_studio_recordable label: "Article", root: false, allowed_parent_types: [ "Workspace", "Folder" ]

  include RecordingStudio::Capabilities::Embeddable.to(
    embed_controller: "articles",
    embed_action: :embed,
    cache: { max_age: 600, stale_while_revalidate: 120 },
    require_publishable: true,
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
        default: "#2563eb"
      },
      font_family: {
        label: "Font",
        css_property: "font-family",
        input: :font_select
      },
      padding_scale: {
        label: "Padding",
        css_property: "padding",
        input: :select,
        choices: [
          ["Compact", "0.5rem"],
          ["Standard", "0.75rem"],
          ["Spacious", "1rem"]
        ],
        default: "0.75rem"
      },
      radius_scale: {
        label: "Corner radius",
        css_property: "border-radius",
        input: :select,
        choices: [
          ["None", "0rem"],
          ["Small", "0.125rem"],
          ["Medium", "0.375rem"],
          ["Large", "0.5rem"],
          ["Extra large", "0.75rem"]
        ],
        default: "0.5rem"
      },
      max_width: {
        label: "Max width",
        css_property: "max-width",
        input: :select,
        choices: [
          ["Reading width", "720px"],
          ["Content width", "960px"],
          ["Wide", "1200px"]
        ],
        default: "960px"
      }
    }
  )

  include RecordingStudio::Capabilities::Publishable.to(
    public_controller: "articles",
    public_action: :show,
    schedule: true,
    seo: false
  )

  def self.recordable_type_label
    "Article"
  end

  class << self
    alias_method :recording_studio_type_label, :recordable_type_label
  end

  def recordable_name
    title.to_s.squish.presence || self.class.recordable_type_label
  end

  alias_method :recording_studio_label, :recordable_name
end
