# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Launcher colours come from the embed theme (accent), not a second editor.
    class Colors
      HEX = /\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\z/
      FALLBACK_BACKGROUND = "#111827"
      FALLBACK_FOREGROUND = "#ffffff"

      def self.call(recording:, embed:)
        tokens = Styling::ResolveTheme.call(recording: recording, embed: embed).tokens
        from_tokens(tokens)
      end

      def self.from_tokens(tokens)
        values = tokens.to_h
        {
          "background" => sanitize(values[:accent_color] || values["accent_color"], FALLBACK_BACKGROUND),
          "foreground" => sanitize(values[:accent_text_color] || values["accent_text_color"], FALLBACK_FOREGROUND)
        }
      end

      def self.sanitize(color, fallback)
        value = color.to_s.strip
        value.match?(HEX) ? value : fallback
      end
    end
  end
end
