# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Recordable
    extend ActiveSupport::Concern

    included do
      class_attribute :recording_studio_embeddable_options, instance_accessor: false, default: nil
      class_attribute :recording_studio_capabilities, instance_accessor: false, default: [] unless
        respond_to?(:recording_studio_capabilities)
    end

    class_methods do
      def recording_studio_embeddable(**options)
        current = recording_studio_embeddable_options || {}
        self.recording_studio_embeddable_options = current.merge(options).reverse_merge(enabled: true)
      end
    end
  end
end
