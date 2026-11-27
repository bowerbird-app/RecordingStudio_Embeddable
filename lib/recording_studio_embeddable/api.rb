# frozen_string_literal: true

require "recording_studio_embeddable/api/embed_recording"
require "recording_studio_embeddable/api/admin_embed_write"
require "recording_studio_embeddable/api/enable_embed_recording"
require "recording_studio_embeddable/api/disable_embed_recording"
require "recording_studio_embeddable/api/copy"
require "recording_studio_embeddable/api/openapi_overrides"
require "recording_studio_embeddable/api/registration"

module RecordingStudioEmbeddable
  module Api
    ACTION_VERSION = "1.0.0"
    PUBLIC_API = :public

    DESCRIPTOR = {
      name: :embed,
      capability: :embeddable,
      version: ACTION_VERSION,
      version_notes: ["Embeddable-owned browser payload action"],
      http_verb: :get,
      scope: :member,
      required_role: :view,
      handler: "RecordingStudioEmbeddable::Api::EmbedRecording"
    }.freeze

    ENABLE_EMBED_DESCRIPTOR = {
      name: :enable_embed,
      capability: :embeddable,
      version: ACTION_VERSION,
      version_notes: ["Embeddable-owned turn-embedding-on action"],
      http_verb: :post,
      scope: :member,
      required_role: :admin,
      handler: "RecordingStudioEmbeddable::Api::EnableEmbedRecording"
    }.freeze

    DISABLE_EMBED_DESCRIPTOR = {
      name: :disable_embed,
      capability: :embeddable,
      version: ACTION_VERSION,
      version_notes: ["Embeddable-owned turn-embedding-off action"],
      http_verb: :post,
      scope: :member,
      required_role: :admin,
      handler: "RecordingStudioEmbeddable::Api::DisableEmbedRecording"
    }.freeze

    class << self
      def descriptor
        DESCRIPTOR
      end

      def enable_embed_descriptor
        ENABLE_EMBED_DESCRIPTOR
      end

      def disable_embed_descriptor
        DISABLE_EMBED_DESCRIPTOR
      end

      def known_action?(name)
        COPY.key?(name.to_sym)
      end

      def summary_for(action)
        COPY.fetch(action.to_sym).fetch(:summary)
      end

      def description_for(action)
        COPY.fetch(action.to_sym).fetch(:description)
      end

      def response_descriptions_for(action)
        COPY.fetch(action.to_sym).fetch(:responses)
      end

      def register_capability_action!
        Registration.register!
      end

      def override_openapi(type:, action:, title:, description: nil)
        OpenapiOverrides.write(type: type, action: action, title: title, description: description)
      end

      def openapi_for(type:, action:)
        OpenapiOverrides.document(type: type, action: action)
      end
    end
  end
end
