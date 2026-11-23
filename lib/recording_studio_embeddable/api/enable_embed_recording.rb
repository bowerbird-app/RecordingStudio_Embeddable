# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Api
    class EnableEmbedRecording
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        authorize_admin!
        recording = context.recording
        unless recording.respond_to?(:embeddable?) && recording.embeddable?
          raise not_found_error(not_embeddable_message)
        end

        embed = enable_embed!(recording)
        result = RenderPayload.call(recording: recording, embed: embed)
        raise render_error(result) if result.failure?

        result.value!.to_h
      end

      private

      attr_reader :context

      def authorize_admin!
        return unless context.respond_to?(:access_grant) && context.access_grant.respond_to?(:authorize!)

        context.access_grant.authorize!(recording: context.recording, role: :admin)
      end

      def enable_embed!(recording)
        embed = recording.ensure_embed!(actor: write_actor)
        return embed if embed.enabled?

        embed.enabled = true
        raise unprocessable_error("Embedding could not be turned on for this recording.") unless embed.persist_changes

        embed
      rescue RecordingStudioEmbeddable::NotEmbeddableError
        raise not_found_error(not_embeddable_message)
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
