# frozen_string_literal: true

require "recording_studio_embeddable/api/embed_recording"

module RecordingStudioEmbeddable
  module Api
    ACTION_VERSION = "1.0.0"

    DESCRIPTOR = {
      name: :embed,
      capability: :embeddable,
      version: ACTION_VERSION,
      version_notes: ["Embeddable-owned browser payload action"],
      http_verb: :get,
      scope: :member,
      required_role: :read,
      handler: "RecordingStudioEmbeddable::Api::EmbedRecording"
    }.freeze

    class << self
      def descriptor
        DESCRIPTOR
      end

      def register_capability_action!
        return unless recording_studio_api_available?

        if named_api_registration_supported?
          RecordingStudioApi.configuration.each_api do |api_definition|
            register_capability_action_for(api_definition.name)
          end
        elsif !RecordingStudioApi.capability_action(:embed)
          RecordingStudioApi.register_capability_action(:embed, **capability_action_options)
        end
      end

      private

      def register_capability_action_for(api_name)
        return if RecordingStudioApi.capability_action(:embed, api: api_name)

        RecordingStudioApi.register_capability_action(:embed, api: api_name, **capability_action_options)
      end

      def named_api_registration_supported?
        RecordingStudioApi.respond_to?(:configuration) &&
          RecordingStudioApi.configuration.respond_to?(:each_api) &&
          action_api_accepts_api?(:capability_action) &&
          action_api_accepts_api?(:register_capability_action)
      end

      def action_api_accepts_api?(method_name)
        RecordingStudioApi.method(method_name).parameters.any? do |type, name|
          type == :keyrest || (name == :api && %i[key keyreq].include?(type))
        end
      end

      def capability_action_options
        {
          capability: DESCRIPTOR[:capability],
          version: DESCRIPTOR[:version],
          version_notes: DESCRIPTOR[:version_notes],
          http_verb: DESCRIPTOR[:http_verb],
          scope: DESCRIPTOR[:scope],
          required_role: DESCRIPTOR[:required_role],
          handler: EmbedRecording,
          openapi: {
            summary: "Embed",
            description: "Returns a browser payload fragment for the recording embed.",
            responses: {
              "200" => { description: "Embed payload rendered successfully." },
              "403" => { description: "API access is not authorized to read this recording." },
              "404" => { description: "Embed was not found for this recording." }
            }
          }
        }
      end

      def recording_studio_api_available?
        defined?(RecordingStudioApi) &&
          RecordingStudioApi.respond_to?(:capability_action) &&
          RecordingStudioApi.respond_to?(:register_capability_action)
      end
    end
  end
end
