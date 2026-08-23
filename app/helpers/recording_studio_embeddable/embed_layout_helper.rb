# frozen_string_literal: true

module RecordingStudioEmbeddable
  module EmbedLayoutHelper
    BODY_STYLE_KEYS = %i[
      font_family
      background_color
      text_color
      muted_text_color
      accent_color
      border_color
      min_height
    ].freeze

    def embed_layout_theme(overrides = nil)
      resolved = defined?(@embed_theme) ? normalize_theme(@embed_theme) : {}
      resolved = resolved.merge(normalize_theme(overrides)) if overrides
      resolved
    end

    def embed_layout_css_variables(overrides = nil)
      theme = embed_layout_theme(overrides)
      variables = []

      BODY_STYLE_KEYS.each do |key|
        definition = embed_layout_definitions[key]
        next unless definition

        value = embed_layout_css_value(key, overrides: theme)
        next if value.blank?

        if definition[:css_variable].present?
          variables << "#{definition[:css_variable]}: #{value}"
        elsif definition[:css_property].present?
          variables << "#{definition[:css_property]}: #{value}"
        end
      end

      variables.join("; ")
    end

    def embed_layout_css_value(key, overrides: nil)
      theme = overrides.is_a?(Hash) ? overrides.symbolize_keys : embed_layout_theme(overrides)
      value = theme[key.to_sym]
      return nil if value.nil?

      definition = embed_layout_definitions[key.to_sym] || {}
      RecordingStudioEmbeddable::Styling::Tokens.css_value_for(key, value, definition: definition)
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

    def embed_layout_definitions
      @embed_layout_definitions ||= RecordingStudioEmbeddable::Styling::Definitions.call(
        recording: embed_layout_recording
      )
    end

    def embed_layout_recording
      @parent_recording || @recording
    end

    def normalize_theme(theme)
      return {} unless theme.respond_to?(:to_h)

      theme.to_h.symbolize_keys
    end
  end
end
