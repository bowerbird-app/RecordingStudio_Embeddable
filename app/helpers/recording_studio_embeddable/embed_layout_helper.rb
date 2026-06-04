# frozen_string_literal: true

module RecordingStudioEmbeddable
  module EmbedLayoutHelper
    THEME_VARIABLE_MAP = {
      font_family: "--rse-embed-font-family",
      background_color: "--rse-embed-background-color",
      text_color: "--rse-embed-text-color",
      muted_text_color: "--rse-embed-muted-text-color",
      accent_color: "--rse-embed-accent-color",
      border_color: "--rse-embed-border-color",
      padding_scale: "--rse-embed-padding",
      radius_scale: "--rse-embed-radius",
      max_width: "--rse-embed-max-width",
      min_height: "--rse-embed-min-height"
    }.freeze

    def embed_layout_theme(overrides = nil)
      resolved = normalize_theme(RecordingStudioEmbeddable.configuration.embed_theme)
      resolved = resolved.merge(normalize_theme(@embed_theme)) if defined?(@embed_theme)
      resolved = resolved.merge(normalize_theme(overrides)) if overrides
      resolved
    end

    def embed_layout_css_variables(overrides = nil)
      theme = embed_layout_theme(overrides)
      variables = []

      THEME_VARIABLE_MAP.each do |key, variable_name|
        value = RecordingStudioEmbeddable::Styling::Tokens.css_value_for(key, theme[key])
        variables << "#{variable_name}: #{value}" if value.present?
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

    def embed_layout_google_font_family(overrides = nil)
      font_family = embed_layout_theme(overrides)[:font_family].to_s.strip
      return nil if font_family.blank?
      return nil if RecordingStudioEmbeddable::Styling::Tokens::FONT_STACKS.key?(font_family)

      font_family
    end

    def embed_layout_google_font_stylesheet_url(font_family)
      return nil if font_family.blank?

      encoded_family = URI.encode_www_form_component(font_family)
      "https://fonts.googleapis.com/css2?family=#{encoded_family}:wght@300;400;500;600;700&display=swap"
    end

    private

    def normalize_theme(theme)
      return {} unless theme.respond_to?(:to_h)

      theme.to_h.symbolize_keys
    end
  end
end
