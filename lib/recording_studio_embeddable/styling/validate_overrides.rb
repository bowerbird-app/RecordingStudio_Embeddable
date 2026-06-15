# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Styling
    class ValidateOverrides
      Result = Struct.new(:cleaned, :errors, keyword_init: true) do
        def valid?
          errors.empty?
        end
      end

        HEX_COLOR = /\A#(?:[0-9a-f]{3}|[0-9a-f]{6})\z/.freeze
        CSS_LENGTH = /\A(?:-?\d+(?:\.\d+)?(?:px|rem|em|vh|vw|%)|auto|none|fit-content|max-content|min-content)\z/i.freeze

      def self.call(...)
        new(...).call
      end

      def initialize(values:, definitions: {})
        @values = values || {}
        @definitions = definitions
      end

      def call
        cleaned = {}
        errors = {}

        values.to_h.each do |raw_key, raw_value|
          key = raw_key.to_s
          definition = definitions[key.to_sym]
          unless definition
            errors[key] = "is not an editable style option"
            next
          end

          cleaned_value, error = validate_value(raw_value, definition)
          if error
            errors[key] = error
          else
            cleaned[key] = cleaned_value
          end
        end

        Result.new(cleaned: cleaned, errors: errors)
      end

      private

      attr_reader :values, :definitions

      def validate_value(raw_value, definition)
        value = raw_value.to_s.strip
        return [nil, nil] if value.blank?

        case definition[:type]
        when :enum
          options = Array(definition[:options]).map(&:to_s)
          return [value, nil] if options.include?(value)

          [nil, "is not in the allowed list"]
        when :color
          normalized = normalize_hex(value)
          return [normalized, nil] if normalized.match?(HEX_COLOR)

          [nil, "must be a valid hex color"]
        when :integer
          integer_value = Integer(value, exception: false)
          return [nil, "must be a number"] if integer_value.nil?
          return [nil, "must be between #{definition[:min]} and #{definition[:max]}"] unless
            integer_value.between?(definition[:min], definition[:max])

          [integer_value, nil]
        when :length
          return [value, nil] if value.match?(CSS_LENGTH)

          [nil, "must be a valid CSS length"]
        when :text
          [value, nil]
        else
          [nil, "has an unsupported type"]
        end
      end

      def normalize_hex(value)
        lowered = value.downcase
        return lowered unless lowered.match?(/\A#[0-9a-f]{3}\z/)

        "##{lowered[1] * 2}#{lowered[2] * 2}#{lowered[3] * 2}"
      end
    end
  end
end