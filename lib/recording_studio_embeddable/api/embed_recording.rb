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
        authorize_edit!
        embed = resolve_embed!
        result = RenderPayload.call(recording: context.recording, embed: embed)
        raise render_error(result) if result.failure?

        result.value!.to_h
      end

      private

      attr_reader :context

      def authorize_edit!
        return unless context.respond_to?(:access_grant) && context.access_grant.respond_to?(:authorize!)

        context.access_grant.authorize!(recording: context.recording, role: :edit)
      end

      def resolve_embed!
        kwargs = {}
        kwargs[:actor] = context.actor if context.respond_to?(:actor)
        context.recording.ensure_embed!(**kwargs)
      end

      def render_error(result)
        message = result.error.to_s
        if defined?(RecordingStudioApi::InvalidActionInputError)
          RecordingStudioApi::InvalidActionInputError.new(message, details: [message])
        else
          StandardError.new(message)
        end
      end
    end
  end
end
