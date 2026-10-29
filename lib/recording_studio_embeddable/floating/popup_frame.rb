# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Optional sandbox and allow attributes for the popup iframe.
    # Keys come from config.floating_defaults, then floating_options.
    # When a key is absent, it is omitted so widget.js keeps today's markup.
    class PopupFrame
      SANDBOX_TOKENS = PopupFrameTokens::SANDBOX_TOKENS
      ALLOW_FEATURES = PopupFrameTokens::ALLOW_FEATURES

      def self.for(recording)
        new(recording).to_h
      end

      def initialize(recording)
        @recording = recording
      end

      def to_h
        sandbox_value = nil
        allow_value = nil
        sandbox_set = false
        allow_set = false

        each_layer do |raw|
          next unless raw.is_a?(Hash)

          if present?(raw, "sandbox")
            sandbox_value = normalize(fetch(raw, "sandbox"), name: "sandbox", known: SANDBOX_TOKENS, joiner: " ")
            sandbox_set = true
          end
          next unless present?(raw, "allow")

          allow_value = normalize(fetch(raw, "allow"), name: "allow", known: ALLOW_FEATURES, joiner: "; ")
          allow_set = true
        end

        attributes = {}
        attributes["sandbox"] = sandbox_value if sandbox_set
        attributes["allow"] = allow_value if allow_set
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

      def present?(raw, key)
        raw.key?(key) || raw.key?(key.to_sym)
      end

      def fetch(raw, key)
        raw.key?(key) ? raw[key] : raw[key.to_sym]
      end

      def normalize(value, name:, known:, joiner:)
        tokens = tokenize(value, name: name)
        raise ArgumentError, "#{name} must include at least one token." if tokens.empty?

        unknown = tokens.find { |token| !known.include?(token) }
        raise ArgumentError, unknown_token_message(name, unknown, known) if unknown

        repeated = tokens.tally.find { |_token, count| count > 1 }
        raise ArgumentError, %(#{name} token "#{repeated.first}" is repeated.) if repeated

        tokens.join(joiner)
      end

      def unknown_token_message(name, unknown, known)
        list = known.join(" ")
        %(Unknown #{name} token "#{unknown}". Known #{name} tokens: #{list}.)
      end

      def tokenize(value, name:)
        case value
        when String, Symbol
          value.to_s.split(/[\s;]+/)
        when Array
          value.flat_map { |item| token_piece(item, name: name) }
        else
          raise ArgumentError, "#{name} must be a string or an array of tokens."
        end
      end

      def token_piece(item, name:)
        case item
        when String, Symbol
          item.to_s.split(/[\s;]+/)
        else
          raise ArgumentError, "#{name} must be a string or an array of tokens."
        end
      end
    end
  end
end
