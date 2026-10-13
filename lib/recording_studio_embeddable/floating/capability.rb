# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Reads the class-level Embeddable opt-in. Types that do not pass
    # floating: true never float.
    class Capability
      def self.for(recording)
        options = Renderer.options_for(recording)
        popup = options[:floating_popup] || options["floating_popup"]
        popup = popup.to_h.transform_keys(&:to_sym) if popup.respond_to?(:to_h)
        new(
          enabled: options[:floating] == true || options["floating"] == true,
          popup: popup || {}
        )
      end

      def initialize(enabled:, popup:)
        @enabled = enabled
        @popup = popup
      end

      def enabled?
        @enabled
      end

      attr_reader :popup

      def controller
        popup[:controller].to_s.sub(%r{\A/}, "").presence
      end

      def action
        popup[:action].to_s.presence
      end
    end
  end
end
