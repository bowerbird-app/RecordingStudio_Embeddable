# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Api
    class EmbedRecording
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        authorize_read!
        embed = resolve_embed!
        result = RenderPayload.call(recording: context.recording, embed: embed)
        raise render_error(result) if result.failure?

        result.value!.to_h
      end

      private

      attr_reader :context

      def authorize_read!
        return unless context.respond_to?(:access_grant) && context.access_grant.respond_to?(:authorize!)

        context.access_grant.authorize!(recording: context.recording, role: :read)
      end

      def resolve_embed!
        recording = context.recording
        embed = if recording.respond_to?(:embed)
                  recording.embed
                end
        return embed unless embed.nil?

        raise not_found_error("Embed was not found for this recording")
      end

      def render_error(result)
        message = result.error.to_s
        if defined?(RecordingStudioApi::InvalidActionInputError)
          RecordingStudioApi::InvalidActionInputError.new(message, details: [message])
        else
          StandardError.new(message)
        end
      end

      def not_found_error(message)
        if defined?(RecordingStudioApi::NotFoundError)
          RecordingStudioApi::NotFoundError.new(message)
        else
          StandardError.new(message)
        end
      end
    end
  end
end
