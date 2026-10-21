# frozen_string_literal: true

module RecordingStudioEmbeddable
  module LogsRegistration
    SOURCE_MODEL = "RecordingStudioEmbeddable::EmbeddableViewLog"
    OWNER = "RecordingStudioEmbeddable"
    FORBIDDEN_AGGREGATABLE = %i[
      bot token_digest viewer_digest
      remote_ip remote_ip_digest user_agent user_agent_digest
      referer referer_digest referer_host
      request_host request_path request_method
    ].freeze

    module_function

    def register!
      return unless defined?(RecordingStudioLogs)

      RecordingStudioLogs.register(
        model: SOURCE_MODEL,
        timestamp_column: :viewed_at,
        partition_interval: nil,
        root_column: :root_recording_id,
        owner: OWNER,
        retention: :indefinite,
        aggregatable: {
          root_recording_id: { filter: [:eq], group: true },
          embed_id: { filter: [:eq], group: true },
          embed_recording_id: { filter: [:eq], group: true },
          parent_recording_id: { filter: [:eq], group: true },
          status: { filter: [:eq], group: true },
          status_code: { filter: [:eq], group: true },
          cache_hit: { filter: [:eq], group: true },
          rate_limited: { filter: [:eq], group: true },
          embed_mode: { filter: [:eq], group: true }
        }
      )

      RecordingStudioLogs.finalize!
    end
  end
end
