# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Styling
    module Tokens
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

      # Curated FlatPack FontSwatch options (label + CSS font-family). Hosts own this list.
      FONT_SWATCH_OPTIONS = [
        ["Sans", "ui-sans-serif, system-ui, sans-serif"],
        ["Serif", "ui-serif, Georgia, serif"],
        ["Mono", "ui-monospace, SFMono-Regular, monospace"]
      ].freeze

      module_function

      def css_value_for(key, value, definition: nil)
        return if value.nil?

        case key.to_sym
        when :font_family
          resolve_font_family_css(value)
        when :padding_scale then SPACING_SCALE[value.to_s] || value.to_s
        when :radius_scale then RADIUS_SCALE[value.to_s] || value.to_s
        else
          normalize_dimension_value(key, value, definition)
        end
      end

      def resolve_font_family_css(value)
        font_value = value.to_s.strip
        return if font_value.blank?
        return FONT_STACKS[font_value] if FONT_STACKS.key?(font_value)
        return font_value if FONT_STACKS.value?(font_value)
        return font_value if FONT_SWATCH_OPTIONS.any? { |_label, css| css == font_value }
        return font_value if font_value.include?(",")

        "\"#{font_value}\", #{FONT_STACKS['sans']}"
      end

      # CSS font-family safe for FlatPack::FontSwatch (AttributeSanitizer).
      def font_swatch_css_for(value)
        font_value = value.to_s.strip
        return FONT_SWATCH_OPTIONS.first[1] if font_value.blank?

        match = FONT_SWATCH_OPTIONS.find { |_label, css| css == font_value }
        return match[1] if match

        case font_value
        when "sans" then FONT_SWATCH_OPTIONS[0][1]
        when "serif" then FONT_SWATCH_OPTIONS[1][1]
        when "mono" then FONT_SWATCH_OPTIONS[2][1]
        else
          FONT_SWATCH_OPTIONS.first[1]
        end
      end

      def font_swatch_label_for(value)
        font_css = font_swatch_css_for(value)
        match = FONT_SWATCH_OPTIONS.find { |_label, css| css == font_css }
        return match[0] if match

        key = value.to_s.strip
        return key.capitalize if FONT_STACKS.key?(key)

        key.presence || "Sans"
      end

      def normalize_dimension_value(key, value, definition)
        property = definition.to_h[:css_property].to_s
        return value.to_s if value.is_a?(String) && value.match?(/\A-?\d+(?:\.\d+)?[a-z%]+\z/i)

        keyword_length = /\A(?:auto|none|fit-content|max-content|min-content)\z/i
        return value.to_s if value.is_a?(String) && value.match?(keyword_length)

        if %i[max_width min_height].include?(key.to_sym) || %w[max-width min-height width height].include?(property)
          return "#{value.to_i}px"
        end

        value
      end
    end
  end
end
