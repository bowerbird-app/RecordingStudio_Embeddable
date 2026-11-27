# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Api
    class DisableEmbedRecording < AdminEmbedWrite
      def call
        authorize_admin!
        recording = require_embeddable_recording!
        embed = disable_embed!(recording)
        payload_for(recording: recording, embed: embed)
      end

      private

      def disable_embed!(recording)
        embed = recording.embed if recording.respond_to?(:embed)
        raise not_found_error(missing_embed_message) if embed.nil?

        persist_enabled!(
          embed,
          enabled: false,
          failure_message: "Embedding could not be turned off for this recording."
        )
      end

      def missing_embed_message
        "Embedding isn't set up for this recording yet. There is no embed to turn off."
      end
    end
  end
end
