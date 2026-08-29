# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Styling
    class ResolveTheme
      Result = Struct.new(:tokens, :sources, keyword_init: true)

      def self.call(...)
        new(...).call
      end

      def initialize(recording:, embed: nil, definitions: Definitions.call(recording: recording))
        @recording = recording
        @embed = embed
        @definitions = normalize_definitions(definitions)
      end

      def call
        values = {}
        sources = {}

        apply_layer!(values, sources, recordable_theme, "recordable")
        apply_layer!(values, sources, embed_theme, "embed")

        Result.new(tokens: values.symbolize_keys, sources: sources.symbolize_keys)
      end

      private

      attr_reader :recording, :embed, :definitions

      def recordable_theme
        @recordable_theme ||= normalize(RecordableDefaults.call(recording: recording)[:defaults])
      end

      def embed_theme
        return {} unless embed.respond_to?(:appearance)

        normalize(embed.appearance)
      end

      def apply_layer!(values, sources, layer, source)
        layer.each do |key, value|
          next unless definitions.key?(key.to_s)
          next if value.nil?

          values[key] = value
          sources[key] = source
        end
      end

      def normalize_definitions(definitions)
        return {} unless definitions.respond_to?(:to_h)

        definitions.to_h.transform_keys(&:to_s)
      end

      def normalize(theme)
        return {} unless theme.respond_to?(:to_h)

        theme.to_h.transform_keys(&:to_s)
      end
    end
  end
end
