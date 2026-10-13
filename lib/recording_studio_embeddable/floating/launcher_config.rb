# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # JSON document for the launcher. Public id is the embed token.
    class LauncherConfig
      def self.call(embed:, recording:, request:)
        new(embed: embed, recording: recording, request: request).call
      end

      def initialize(embed:, recording:, request:)
        @embed = embed
        @recording = recording
        @request = request
      end

      def call
        return unless embed&.floating_enabled?
        return unless capability.enabled?

        validated = Schema.validate(embed.read_attribute(:floating), recording: recording)
        return unless validated.valid?

        popup_url = PopupUrl.call(recording: recording, token: embed.token, request: request)
        return if popup_url.blank?

        settings = validated.settings
        {
          "id" => embed.token,
          "title" => title,
          "position" => settings["position"],
          "edge_spacing" => settings["edge_spacing"],
          "popup_width" => settings["popup_width"],
          "popup_height" => settings["popup_height"],
          "icon_url" => settings["icon_url"],
          "colors" => Colors.call(recording: recording, embed: embed),
          "popup_url" => popup_url
        }
      end

      private

      attr_reader :embed, :recording, :request

      def capability
        @capability ||= Capability.for(recording)
      end

      def title
        recordable = recording.respond_to?(:recordable) ? recording.recordable : nil
        recordable.try(:title).presence || recordable.try(:name).presence || "Chat"
      end
    end
  end
end
