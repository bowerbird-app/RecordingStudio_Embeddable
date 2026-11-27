# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Api
    class AdminEmbedWrite
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      private

      attr_reader :context

      def authorize_admin!
        return unless context.respond_to?(:access_grant) && context.access_grant.respond_to?(:authorize!)

        context.access_grant.authorize!(recording: context.recording, role: :admin)
      end

      def require_embeddable_recording!
        recording = context.recording
        unless recording.respond_to?(:embeddable?) && recording.embeddable?
          raise not_found_error(not_embeddable_message)
        end

        recording
      end

      def persist_enabled!(embed, enabled:, failure_message:)
        return embed if embed.enabled? == enabled

        embed.enabled = enabled
        raise unprocessable_error(failure_message) unless embed.persist_changes

        embed
      end

      def payload_for(recording:, embed:)
        result = RenderPayload.call(recording: recording, embed: embed)
        raise render_error(result) if result.failure?

        result.value!.to_h
      end

      def write_actor
        grant = context.access_grant if context.respond_to?(:access_grant)
        grant.actor if grant.respond_to?(:actor)
      end

      def not_embeddable_message
        "This recording is not embeddable."
      end

      def render_error(result)
        message = result.error.to_s
        if defined?(RecordingStudioApi::InvalidActionInputError)
          RecordingStudioApi::InvalidActionInputError.new(message, details: [message])
        else
          StandardError.new(message)
        end
      end

      def unprocessable_error(message)
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
