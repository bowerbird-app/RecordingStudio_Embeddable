# frozen_string_literal: true

module RecordingStudioEmbeddable
  module LogsRegistration
    SOURCE_MODEL = "RecordingStudioEmbeddable::EmbeddableViewLog"
    EMBED_VIEWS = "embeddable/embed_views"
    OWNER = "RecordingStudioEmbeddable"
    FORBIDDEN_AGGREGATABLE = %i[
      bot token_digest viewer_digest
      remote_ip remote_ip_digest user_agent user_agent_digest
      referer referer_digest referer_host
      request_host request_path request_method
    ].freeze

    module_function

    def summaries_enabled?
      RecordingStudioEmbeddable.configuration.logs_summaries_enabled
    end

    def logging_connection
      EmbeddableViewLog.connection
    end

    def resolved_retention
      duration = RecordingStudioEmbeddable.configuration.prune_views_after
      return :indefinite if duration.blank?

      duration
    end

    def register!
      return unless defined?(RecordingStudioLogs)

      RecordingStudioLogs.register(
        model: SOURCE_MODEL,
        timestamp_column: :viewed_at,
        partition_interval: nil,
        root_column: :root_recording_id,
        owner: OWNER,
        retention: resolved_retention,
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

      RecordingStudioLogs.aggregate(
        source: SOURCE_MODEL,
        name: EMBED_VIEWS,
        summary_model: "RecordingStudioEmbeddable::EmbeddableViewDaySummary",
        owner: OWNER,
        group_by: %i[root_recording_id embed_id parent_recording_id status],
        measurements: {
          view_count: :count
        }
      )

      RecordingStudioLogs.finalize!
    end

    def embed_views_definition
      RecordingStudioLogs.registry.aggregation(EMBED_VIEWS)
    end
  end
end
