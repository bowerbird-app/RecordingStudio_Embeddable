begin
  require "recording_studio_publishable"
rescue LoadError
  nil
end

class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false, allowed_parent_types: [ "Workspace", "Folder" ]

  if defined?(RecordingStudioPublishable::ParentRecordable)
    include RecordingStudioPublishable::ParentRecordable

    recording_studio_publishable(
      public_controller: "pages",
      public_action: :show,
      schedule: true,
      seo: false
    )
  end

  include RecordingStudio::Capabilities::Embeddable.to(
    embed_controller: "pages",
    embed_action: :embed,
    require_publishable: defined?(RecordingStudioPublishable),
    customizable_embed_styles: {
      background_color: {
        label: "Background Color",
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
      muted_text_color: {
        label: "Muted text color",
        css_variable: "--surface-muted-content-color",
        input: :color,
        default: "#475569"
      },
      accent_color: {
        label: "Accent color",
        css_variable: "--color-primary",
        input: :color,
        default: "#2563eb"
      },
      border_color: {
        label: "Border color",
        css_variable: "--surface-border-color",
        input: :color,
        default: "#e2e8f0"
      },
      page_background_color: {
        label: "Page background color",
        css_variable: "--surface-page-background-color",
        input: :color,
        default: "#f8fafc"
      },
      muted_background_color: {
        label: "Muted background color",
        css_variable: "--surface-muted-background-color",
        input: :color,
        default: "#f1f5f9"
      },
      border_hover_color: {
        label: "Border hover color",
        css_variable: "--surface-border-hover-color",
        input: :color,
        default: "#cbd5e1"
      },
      accent_hover_color: {
        label: "Accent hover color",
        css_variable: "--color-primary-hover",
        input: :color,
        default: "#1d4ed8"
      },
      accent_text_color: {
        label: "Accent text color",
        css_variable: "--color-primary-text",
        input: :color,
        default: "#ffffff"
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
          ["None", "0rem"],
          ["Extra small", "0.25rem"],
          ["Small", "0.5rem"],
          ["Medium", "0.75rem"],
          ["Large", "1rem"],
          ["Extra large", "1.5rem"]
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
        default: "0.375rem"
      },
      radius_sm: {
        label: "Radius small token",
        css_variable: "--radius-sm",
        input: :select,
        choices: [
          ["Extra small", "0.125rem"],
          ["Small", "0.25rem"],
          ["Medium", "0.375rem"],
          ["Large", "0.5rem"]
        ],
        default: "0.25rem"
      },
      radius_md: {
        label: "Radius medium token",
        css_variable: "--radius-md",
        input: :select,
        choices: [
          ["Small", "0.25rem"],
          ["Medium", "0.375rem"],
          ["Large", "0.5rem"],
          ["Extra large", "0.75rem"]
        ],
        default: "0.375rem"
      },
      radius_lg: {
        label: "Radius large token",
        css_variable: "--radius-lg",
        input: :select,
        choices: [
          ["Medium", "0.375rem"],
          ["Large", "0.5rem"],
          ["Extra large", "0.75rem"],
          ["2XL", "1rem"]
        ],
        default: "0.5rem"
      },
      radius_xl: {
        label: "Radius XL token",
        css_variable: "--radius-xl",
        input: :select,
        choices: [
          ["Large", "0.5rem"],
          ["Extra large", "0.75rem"],
          ["2XL", "1rem"],
          ["3XL", "1.25rem"]
        ],
        default: "0.75rem"
      },
      stack_gap_sm: {
        label: "Stack gap small token",
        css_variable: "--stack-gap-sm",
        input: :select,
        choices: [
          ["Tight", "0.5rem"],
          ["Default", "0.75rem"],
          ["Relaxed", "1rem"]
        ],
        default: "0.5rem"
      },
      stack_gap_md: {
        label: "Stack gap medium token",
        css_variable: "--stack-gap-md",
        input: :select,
        choices: [
          ["Default", "0.75rem"],
          ["Relaxed", "1rem"],
          ["Spacious", "1.25rem"]
        ],
        default: "0.75rem"
      },
      stack_gap_lg: {
        label: "Stack gap large token",
        css_variable: "--stack-gap-lg",
        input: :select,
        choices: [
          ["Relaxed", "1rem"],
          ["Spacious", "1.25rem"],
          ["Extra spacious", "1.5rem"]
        ],
        default: "1rem"
      },
      max_width: {
        label: "Max width",
        css_property: "max-width",
        input: :select,
        choices: [
          ["Smallest", "100px"],
          ["Small", "640px"],
          ["Medium", "960px"],
          ["Large", "1200px"]
        ],
        default: "1200px"
      },
      min_height: {
        label: "Min height",
        css_property: "min-height",
        input: :select,
        choices: [
          ["Compact", "240px"],
          ["Standard", "320px"],
          ["Tall", "480px"]
        ],
        default: "320px"
      }
    }
  )

  def self.recordable_type_label
    "Page"
  end

  class << self
    alias_method :recording_studio_type_label, :recordable_type_label
  end

  def recordable_name
    title.to_s.squish.presence || self.class.recordable_type_label
  end

  alias_method :recording_studio_label, :recordable_name
end
