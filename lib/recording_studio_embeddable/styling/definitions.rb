# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Styling
    class Definitions
      def self.call(...)
        new(...).call
      end

      def initialize(recording:)
        @recording = recording
      end

      def call
        declared = RecordingStudioEmbeddable::Renderer.options_for(recording)[:customizable_embed_styles]
        return {} if declared.blank?

        normalize_definitions(declared)
      end

      private

      attr_reader :recording

      def normalize_definitions(definitions)
        definitions.each_with_object({}) do |(key, definition), normalized|
          next unless definition.respond_to?(:to_h)

          field = definition.to_h.symbolize_keys
          input = field[:input]&.to_sym

          normalized[key.to_sym] = field.merge(
            input: input,
            type: normalize_type(input, field),
            options: normalize_options(field[:choices]),
            option_items: normalize_option_items(field[:choices])
          ).compact
        end
      end

      def normalize_type(input, field)
        return field[:type] if field[:type].present?

        case input
        when :color then :color
        when :select, :font_select then :enum
        when :integer then :integer
        when :length then :length
        when :text then :text
        end
      end

      def normalize_options(choices)
        return nil if choices.blank?

        Array(choices).filter_map do |choice|
          case choice
          when Hash
            choice[:value] || choice["value"]
          when Array
            choice[1] || choice[0]
          else
            choice
          end
        end
      end

      def normalize_option_items(choices)
        return nil if choices.blank?

        Array(choices).filter_map do |choice|
          case choice
          when Hash
            value = choice[:value] || choice["value"]
            label = choice[:label] || choice["label"] || value
            next if value.blank?

            { label: label, value: value }
          when Array
            value = choice[1] || choice[0]
            next if value.blank?

            { label: choice[0] || value, value: value }
          else
            next if choice.blank?

            { label: choice, value: choice }
          end
        end
      end
    end
  end
end
