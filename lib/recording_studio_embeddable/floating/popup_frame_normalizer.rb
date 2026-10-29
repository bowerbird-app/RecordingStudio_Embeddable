# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Checks sandbox and allow once, when config is assigned or a type registers.
    module PopupFrameNormalizer
      module_function

      def normalize_layer(raw, name:)
        raise ArgumentError, "#{name} must be a hash." unless raw.is_a?(Hash)

        copy = raw.deep_dup
        write_canonical(copy, "sandbox")
        write_canonical(copy, "allow")
        deep_freeze(copy)
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each_value { |item| deep_freeze(item) }
          value.freeze
        when Array
          value.each { |item| deep_freeze(item) }
          value.freeze
        else
          value.freeze if value.respond_to?(:freeze)
          value
        end
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
        raise_origin_list!(token) if origin_list?(token, name: name)

        known = name == "allow" ? PopupFrame::ALLOW_FEATURES : PopupFrame::SANDBOX_TOKENS
        return if known.include?(token)

        list = known.join(" ")
        raise ArgumentError, %(Unknown #{name} token "#{token}". Known #{name} tokens: #{list}.)
      end

      def origin_list?(token, name:)
        return false unless name == "allow"
        return false if PopupFrame::BARE_ALLOW_FEATURE.match?(token)

        !token.match?(/\A[A-Za-z0-9-]+\z/)
      end

      def raise_origin_list!(token)
        example = "\"camera 'self'\""
        offending = "\"#{token}\""
        message = "allow accepts bare feature names only. Origin lists such as #{example} are rejected. " \
                  "Offending token: #{offending}."
        raise ArgumentError, message
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
