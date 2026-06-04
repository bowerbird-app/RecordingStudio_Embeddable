# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Styling
    module Tokens
      REGISTRY = {
        font_family: {
          label: "Font",
          type: :enum,
          # Populated at runtime from Google Fonts in management flows.
          options: [],
          default: "sans",
          css_variable: "--rse-embed-font-family"
        },
        background_color: {
          label: "Background Color",
          type: :color,
          default: "#ffffff",
          css_variable: "--rse-embed-background-color"
        },
        text_color: {
          label: "Text Color",
          type: :color,
          default: "#0f172a",
          css_variable: "--rse-embed-text-color"
        },
        muted_text_color: {
          label: "Muted Text Color",
          type: :color,
          default: "#475569",
          css_variable: "--rse-embed-muted-text-color"
        },
        accent_color: {
          label: "Accent Color",
          type: :color,
          default: "#2563eb",
          css_variable: "--rse-embed-accent-color"
        },
        border_color: {
          label: "Border Color",
          type: :color,
          default: "#e2e8f0",
          css_variable: "--rse-embed-border-color"
        },
        padding_scale: {
          label: "Padding",
          type: :enum,
          options: %w[none xs sm md lg xl],
          default: "md",
          css_variable: "--rse-embed-padding"
        },
        radius_scale: {
          label: "Corner Radius",
          type: :enum,
          options: %w[none sm md lg xl],
          default: "md",
          css_variable: "--rse-embed-radius"
        },
        max_width: {
          label: "Max Width",
          type: :integer,
          min: 280,
          max: 1600,
          default: 1200,
          css_variable: "--rse-embed-max-width"
        },
        min_height: {
          label: "Min Height",
          type: :integer,
          min: 160,
          max: 1600,
          default: 320,
          css_variable: "--rse-embed-min-height"
        }
      }.freeze

      SPACING_SCALE = {
        "none" => "0rem",
        "xs" => "0.25rem",
        "sm" => "0.5rem",
        "md" => "0.75rem",
        "lg" => "1rem",
        "xl" => "1.5rem"
      }.freeze

      RADIUS_SCALE = {
        "none" => "0rem",
        "sm" => "0.125rem",
        "md" => "0.375rem",
        "lg" => "0.5rem",
        "xl" => "0.75rem"
      }.freeze

      FONT_STACKS = {
        "sans" => "ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif",
        "serif" => "ui-serif, Georgia, Cambria, Times New Roman, serif",
        "mono" => "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace"
      }.freeze

      module_function

      def definitions
        REGISTRY
      end

      def editable_keys
        REGISTRY.keys.map(&:to_s)
      end

      def default_values
        REGISTRY.transform_values { |config| config[:default] }
      end

      def css_value_for(key, value)
        return if value.nil?

        case key.to_sym
        when :font_family
          font_key = value.to_s
          FONT_STACKS[font_key] || "\"#{font_key}\", #{FONT_STACKS["sans"]}"
        when :padding_scale then SPACING_SCALE[value.to_s] || SPACING_SCALE["md"]
        when :radius_scale then RADIUS_SCALE[value.to_s] || RADIUS_SCALE["md"]
        when :max_width, :min_height then "#{value.to_i}px"
        else value
        end
      end
    end
  end
end