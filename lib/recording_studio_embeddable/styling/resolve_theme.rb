# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Styling
    class ResolveTheme
      Result = Struct.new(:values, :sources, keyword_init: true)

      def self.call(...)
        new(...).call
      end

      def initialize(recording:, embed: nil, global_theme: RecordingStudioEmbeddable.configuration.embed_theme,
                     token_defaults: Tokens.default_values)
        @recording = recording
        @embed = embed
        @global_theme = normalize(global_theme)
        @token_defaults = normalize(token_defaults)
      end

      def call
        values = token_defaults.dup
        sources = values.keys.index_with { "system" }

        apply_layer!(values, sources, global_theme, "global")
        apply_layer!(values, sources, recordable_theme, "recordable")
        apply_layer!(values, sources, embed_theme, "embed")

        Result.new(values: values.symbolize_keys, sources: sources.symbolize_keys)
      end

      private

      attr_reader :recording, :embed, :global_theme, :token_defaults

      def recordable_theme
        @recordable_theme ||= normalize(RecordableDefaults.call(recording: recording)[:defaults])
      end

      def embed_theme
        return {} unless embed.respond_to?(:appearance)

        normalize(embed.appearance)
      end

      def apply_layer!(values, sources, layer, source)
        layer.each do |key, value|
          next unless Tokens.definitions.key?(key.to_sym)
          next if value.nil?

          values[key] = value
          sources[key] = source
        end
      end

      def normalize(theme)
        return {} unless theme.respond_to?(:to_h)

        theme.to_h.transform_keys(&:to_s)
      end
    end
  end
end