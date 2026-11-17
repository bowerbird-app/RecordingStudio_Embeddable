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
      required_role: :view,
      handler: "RecordingStudioEmbeddable::Api::EmbedRecording"
    }.freeze

    ACTION_SUMMARY = "Get the embed payload for this recording."
    ACTION_DESCRIPTION =
      "An embed lets this recording be shown inside another web page. " \
      "This returns the recording's embed as a browser payload: a cleaned HTML " \
      "fragment plus its display settings, ready for the embed script to place " \
      "on a page. Run it on the recording itself, using that recording's id " \
      "(the same id you use for its other actions). The recording must already " \
      "have an embed, set up in the app's embed settings; this action only " \
      "reads and never creates one. A recording id that is not found is " \
      "rejected. A recording with no embed is rejected " \
      "(\"Embed was not found for this recording\"). If the embed can't be " \
      "rendered, the call is rejected as invalid. Repeat calls change nothing " \
      "and return the same payload while the embed is unchanged. Returns " \
      "schema_version (1), html (the cleaned fragment), configuration (theme " \
      "and sizing), and sdk.minimum_version (the oldest embed script version " \
      "that can show it)."
    ACTION_RESPONSE_DESCRIPTIONS = {
      "200" => "The embed payload for this recording.",
      "403" => "The caller is not allowed to view this recording.",
      "404" => "This recording was not found, or it has no embed."
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
            summary: ACTION_SUMMARY,
            description: ACTION_DESCRIPTION,
            responses: ACTION_RESPONSE_DESCRIPTIONS.transform_values { |text| { description: text } }
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
