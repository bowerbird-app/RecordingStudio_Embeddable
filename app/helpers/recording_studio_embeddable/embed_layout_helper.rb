# frozen_string_literal: true

module RecordingStudioEmbeddable
  module EmbedLayoutHelper
    THEME_VARIABLE_MAP = {
      font_family: "--rse-embed-font-family",
      background_color: "--rse-embed-background-color",
      text_color: "--rse-embed-text-color",
      muted_text_color: "--rse-embed-muted-text-color",
      accent_color: "--rse-embed-accent-color",
      border_color: "--rse-embed-border-color"
    }.freeze

    def embed_layout_theme(overrides = nil)
      base_theme = RecordingStudioEmbeddable.configuration.embed_theme
      resolved = normalize_theme(base_theme)
      resolved = merge_theme(resolved, normalize_theme(@embed_theme)) if defined?(@embed_theme)
      resolved = merge_theme(resolved, normalize_theme(overrides)) if overrides
      resolved
    end

    def embed_layout_css_variables(overrides = nil)
      theme = embed_layout_theme(overrides)
      variables = []

      THEME_VARIABLE_MAP.each do |key, variable_name|
        value = theme[key]
        variables << "#{variable_name}: #{value}" if value.present?
      end

      theme.fetch(:custom_properties, {}).each do |name, value|
        next unless name.to_s.start_with?("--")

        variables << "#{name}: #{value}"
      end

      variables.join("; ")
    end

    def embed_layout_body_attributes(overrides: nil, extra_class: nil)
      classes = ["recording-studio-embed-layout", extra_class].compact.join(" ")
      style = embed_layout_css_variables(overrides)

      {
        class: classes,
        style: style.presence,
        data: { recording_studio_embeddable: "embed-layout" }
      }
    end

    private

    def normalize_theme(theme)
      return { custom_properties: {} } unless theme.respond_to?(:to_h)

      normalized = theme.to_h.symbolize_keys
      normalized[:custom_properties] = normalized.fetch(:custom_properties, {}).to_h.stringify_keys
      normalized
    end

    def merge_theme(base, overrides)
      merged = base.merge(overrides)
      merged[:custom_properties] = base.fetch(:custom_properties, {}).merge(overrides.fetch(:custom_properties, {}))
      merged
    end
  end
end
