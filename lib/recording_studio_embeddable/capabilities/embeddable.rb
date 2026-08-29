# frozen_string_literal: true

module RecordingStudio
  module Capabilities
    class Embeddable < Module
      attr_reader :options

      def self.key
        :embeddable
      end

      def self.to(**)
        new(**)
      end

      def initialize(**options)
        super()
        @options = options.reverse_merge(enabled: true)
      end

      def key
        self.class.key
      end

      def included(recordable_class)
        ensure_recordable_api!(recordable_class)
        recordable_class.recording_studio_embeddable(**options)
        recordable_class.recording_studio_capabilities += [self]
      end

      def apply(recordable_class)
        included(recordable_class)
      end

      private

      def ensure_recordable_api!(recordable_class)
        recordable_class.include RecordingStudioEmbeddable::Recordable unless
          recordable_class.respond_to?(:recording_studio_embeddable)

        return if recordable_class.respond_to?(:recording_studio_capabilities)

        recordable_class.class_attribute :recording_studio_capabilities, instance_accessor: false, default: []
      end
    end
  end
end
