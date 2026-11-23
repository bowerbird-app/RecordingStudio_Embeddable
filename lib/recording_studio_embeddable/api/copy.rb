# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Api
    ACTION_SUMMARY = "Get the embed payload for this recording."
    ACTION_DESCRIPTION =
      "An embed lets this recording be shown inside another web page. " \
      "This returns the recording's embed as a browser payload: a cleaned HTML " \
      "fragment plus its display settings, ready for the embed script to place " \
      "on a page. You need view access on the recording. Run it on the " \
      "recording itself, using that recording's id (the same id you use for " \
      "its other actions). This action only reads. The recording must already " \
      "have embedding turned on. Turn embedding on once with enable_embed, or " \
      "open the Embed screen once. This action never creates an embed. A " \
      "recording that is not found, or one where embedding is not enabled " \
      "yet, is rejected. If the embed can't be rendered, the call is " \
      "rejected as invalid. Repeat calls change nothing and return the same " \
      "payload while the embed is unchanged. Returns schema_version (1), html " \
      "(the cleaned fragment), configuration (theme and sizing), and " \
      "sdk.minimum_version (the oldest embed script version that can show it)."
    ACTION_RESPONSE_DESCRIPTIONS = {
      "200" => "The embed payload for this recording.",
      "403" => "The caller does not have view access on this recording.",
      "404" => "This recording was not found, or embedding is not enabled yet. " \
               "Turn embedding on once with enable_embed, or open the Embed screen once."
    }.freeze

    ENABLE_EMBED_ACTION_SUMMARY = "Turn embedding on for this recording."
    ENABLE_EMBED_ACTION_DESCRIPTION =
      "An embed lets this recording be shown inside another web page. " \
      "This turns embedding on so the recording can be embedded publicly on other sites. " \
      "The recording must already exist, be published, and be embeddable. " \
      "Run it on the recording itself, using that recording's id (the same id you use for " \
      "its other actions). Send no body fields. A recording that is not found, or one that is " \
      "not embeddable, is rejected. If embedding is already on, the call succeeds and writes " \
      "nothing new. It does not create a second embed. Returns schema_version (1), html " \
      "(the cleaned fragment), configuration (theme and sizing), and sdk.minimum_version " \
      "(the oldest embed script version that can show it)."
    ENABLE_EMBED_ACTION_RESPONSE_DESCRIPTIONS = {
      "200" => "Embedding is on. The embed payload for this recording.",
      "403" => "The caller cannot turn embedding on for this recording.",
      "404" => "This recording was not found, or it is not embeddable.",
      "422" => "Embedding could not be turned on for this recording."
    }.freeze

    COPY = {
      embed: {
        summary: ACTION_SUMMARY,
        description: ACTION_DESCRIPTION,
        responses: ACTION_RESPONSE_DESCRIPTIONS
      },
      enable_embed: {
        summary: ENABLE_EMBED_ACTION_SUMMARY,
        description: ENABLE_EMBED_ACTION_DESCRIPTION,
        responses: ENABLE_EMBED_ACTION_RESPONSE_DESCRIPTIONS
      }
    }.freeze
  end
end
