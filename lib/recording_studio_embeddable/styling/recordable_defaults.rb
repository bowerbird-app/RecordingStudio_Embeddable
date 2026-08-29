# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Styling
    class RecordableDefaults
      def self.call(...)
        new(...).call
      end

      def initialize(recording:)
        @recording = recording
      end

      def call
        options = RecordingStudioEmbeddable::Renderer.options_for(recording)
        defaults = normalize(definitions_default_values)
        allow_custom_styling = options.key?(:allow_custom_styling) ? cast_boolean(options[:allow_custom_styling]) : true

        {
          recordable_type: recordable_type,
          defaults: defaults,
          allow_custom_styling: allow_custom_styling
        }
      end

      private

      attr_reader :recording

      def recordable_type
        type_from_recording = recording.respond_to?(:recordable_type) ? recording.recordable_type : nil
        type_from_recording.presence || (recording.respond_to?(:recordable) ? recording.recordable&.class&.name : nil)
      end

      def definitions_default_values
        Definitions.call(recording: recording).each_with_object({}) do |(key, definition), values|
          next unless definition.respond_to?(:to_h)

          default = definition.to_h[:default]
          values[key] = default unless default.nil?
        end
      end

      def normalize(values)
        return {} unless values.respond_to?(:to_h)

        values.to_h.transform_keys(&:to_s)
      end

      def cast_boolean(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end
    end
  end
end
