# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Checks sandbox and allow once, when config is assigned or a type registers.
    module PopupFrameNormalizer
      module_function

      def normalize_layer(raw, name:)
        raise ArgumentError, "#{name} must be a hash." unless raw.is_a?(Hash)

        copy = raw.dup
        write_canonical(copy, "sandbox")
        write_canonical(copy, "allow")
        copy
      end

      def write_canonical(copy, key)
        return unless copy.key?(key) || copy.key?(key.to_sym)

        canonical = canonicalize(fetch(copy, key), name: key)
        if copy.key?(key)
          copy[key] = canonical
        else
          copy[key.to_sym] = canonical
        end
      end

      def canonicalize(value, name:)
        tokens = tokenize(value, name: name)
        raise ArgumentError, "#{name} must include at least one token." if tokens.empty?

        tokens.each { |token| assert_token!(token, name: name) }
        repeated = tokens.tally.find { |_token, count| count > 1 }
        raise ArgumentError, %(#{name} token "#{repeated.first}" is repeated.) if repeated

        tokens.join(name == "allow" ? "; " : " ")
      end

      def assert_token!(token, name:)
        if name == "allow" && !PopupFrame::BARE_ALLOW_FEATURE.match?(token)
          raise ArgumentError,
                %(allow accepts bare feature names only. Origin lists such as "camera 'self'" are rejected.)
        end

        known = name == "allow" ? PopupFrame::ALLOW_FEATURES : PopupFrame::SANDBOX_TOKENS
        return if known.include?(token)

        list = known.join(" ")
        raise ArgumentError, %(Unknown #{name} token "#{token}". Known #{name} tokens: #{list}.)
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

      def fetch(raw, key)
        raw.key?(key) ? raw[key] : raw[key.to_sym]
      end
    end
  end
end
