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
        defaults = normalize(options[:embed_theme])
        allow_custom_styling = options.key?(:allow_custom_styling) ? cast_boolean(options[:allow_custom_styling]) : true

        profile = load_profile
        if profile
          defaults.merge!(normalize(profile.defaults))
          allow_custom_styling = cast_boolean(profile.allow_custom_styling)
        end

        {
          recordable_type: recordable_type,
          defaults: defaults,
          allow_custom_styling: allow_custom_styling,
          profile: profile
        }
      end

      private

      attr_reader :recording

      def recordable_type
        type_from_recording = recording.respond_to?(:recordable_type) ? recording.recordable_type : nil
        type_from_recording.presence || (recording.respond_to?(:recordable) ? recording.recordable&.class&.name : nil)
      end

      def load_profile
        return unless defined?(RecordingStudioEmbeddable::StylingProfile)
        return if recordable_type.blank?
        return unless RecordingStudioEmbeddable::StylingProfile.table_exists?

        RecordingStudioEmbeddable::StylingProfile.find_by(recordable_type: recordable_type)
      rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
        nil
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