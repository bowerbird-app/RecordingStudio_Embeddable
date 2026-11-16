# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Public launcher and popup gate. Management preview does not call this.
    class PublicDocument
      def self.available?(embed:, recording:, request:)
        new(embed: embed, recording: recording, request: request).available?
      end

      def initialize(embed:, recording:, request:)
        @embed = embed
        @recording = recording
        @request = request
      end

      def available?
        return false unless embed&.floating_enabled?
        return false if recording.nil? || trashed?
        return false unless Capability.for(recording).enabled?

        # Domain blocks stay on the launcher allowlist and the popup frame policy.
        access.allowed? || access.reason == :domain_blocked
      end

      private

      attr_reader :embed, :recording, :request

      def trashed?
        recording.respond_to?(:trashed_at) && recording.trashed_at.present?
      end

      def access
        @access ||= Security::PublicAccess.call(
          embed: embed,
          request: request,
          recording: recording,
          options: Renderer.options_for(recording)
        )
      end
    end
  end
end
