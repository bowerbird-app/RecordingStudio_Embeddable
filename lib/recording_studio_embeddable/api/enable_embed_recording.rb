# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Api
    class EnableEmbedRecording < AdminEmbedWrite
      def call
        authorize_admin!
        recording = require_embeddable_recording!
        embed = enable_embed!(recording)
        payload_for(recording: recording, embed: embed)
      end

      private

      def enable_embed!(recording)
        embed = recording.ensure_embed!(actor: write_actor)
        persist_enabled!(
          embed,
          enabled: true,
          failure_message: "Embedding could not be turned on for this recording."
        )
      rescue RecordingStudioEmbeddable::NotEmbeddableError
        raise not_found_error(not_embeddable_message)
      end
    end
  end
end
