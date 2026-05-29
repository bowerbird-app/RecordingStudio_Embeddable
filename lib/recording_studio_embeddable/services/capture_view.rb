# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Services
    class CaptureView
      def self.call(embed:, request:, status: "rendered", status_code: 200, cache_hit: false, rate_limited: false,
                    metadata: {})
        return unless RecordingStudioEmbeddable.configuration.view_logging_enabled

        payload = NormalizePayload.call(request)
        if RecordingStudioEmbeddable.configuration.async_view_logging && defined?(RecordingStudioEmbeddable::LogViewJob)
          RecordingStudioEmbeddable::LogViewJob.perform_later(embed&.id, payload, status, status_code, cache_hit,
                                                              rate_limited, metadata)
        else
          LogView.call(embed: embed, payload: payload, status: status, status_code: status_code,
                       cache_hit: cache_hit, rate_limited: rate_limited, metadata: metadata)
        end
      rescue StandardError => e
        if defined?(Rails) && Rails.logger
          Rails.logger.info("[RecordingStudioEmbeddable] view capture skipped: #{e.class}")
        end
        nil
      end
    end
  end
end
