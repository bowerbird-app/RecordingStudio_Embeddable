# frozen_string_literal: true

module RecordingStudioEmbeddable
  class LogViewJob < ActiveJob::Base
    queue_as { RecordingStudioEmbeddable.configuration.view_logging_queue || :default }

    retry_on StandardError, attempts: 3

    def perform(embed_id, payload, status = "rendered", status_code = 200, cache_hit = false, rate_limited = false,
                metadata = {})
      embed = Embed.find_by(id: embed_id) if embed_id.present?
      Services::LogView.call(embed: embed, payload: payload, status: status, status_code: status_code,
                             cache_hit: cache_hit, rate_limited: rate_limited, metadata: metadata || {})
    end
  end
end
