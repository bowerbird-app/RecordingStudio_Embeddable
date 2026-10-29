# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Optional sandbox and allow attributes for the popup iframe.
    # Those keys are normalized when config is assigned and when a type
    # registers. Rendering only reads the stored strings.
    class PopupFrame
      SANDBOX_TOKENS = PopupFrameTokens::SANDBOX_TOKENS
      ALLOW_FEATURES = PopupFrameTokens::ALLOW_FEATURES
      BARE_ALLOW_FEATURE = /\A[a-z0-9-]+\z/

      def self.normalize_layer(raw, name:)
        PopupFrameNormalizer.normalize_layer(raw, name: name)
      end

      def self.normalize_floating_options!(options)
        key = floating_options_key(options)
        return unless key

        options[key] = normalize_layer(options[key], name: "floating_options")
      end

      def self.floating_options_key(options)
        return :floating_options if options.key?(:floating_options)
        return "floating_options" if options.key?("floating_options")

        nil
      end

      def self.for(recording)
        new(recording).to_h
      end

      def initialize(recording)
        @recording = recording
      end

      def to_h
        attributes = {}
        each_layer do |raw|
          next unless raw.is_a?(Hash)

          copy_stored(attributes, raw, "sandbox", " ")
          copy_stored(attributes, raw, "allow", "; ")
        end
        attributes
      end

      private

      attr_reader :recording

      def each_layer
        yield RecordingStudioEmbeddable.configuration.floating_defaults
        yield capability_options
      end

      def capability_options
        return {} if recording.nil?

        options = Renderer.options_for(recording)
        options[:floating_options] || options["floating_options"] || {}
      end

      def copy_stored(attributes, raw, key, joiner)
        return unless raw.key?(key) || raw.key?(key.to_sym)

        value = raw.key?(key) ? raw[key] : raw[key.to_sym]
        text = case value
               when Array
                 value.map(&:to_s).join(joiner)
               when String, Symbol
                 value.to_s
               end
        return if text.nil? || text.empty?

        attributes[key] = text
      end
    end
  end
end
