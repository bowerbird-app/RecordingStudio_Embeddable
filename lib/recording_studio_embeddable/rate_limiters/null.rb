# frozen_string_literal: true

module RecordingStudioEmbeddable
  module RateLimiters
    # Thin adapter over RecordingStudioCache::RateLimiter (:null backend).
    class Null
      def self.allow?(key: "null", limit: 1, window: 60, **)
        RecordingStudioCache::RateLimiter.allow?(
          key: key,
          limit: limit,
          window: window,
          backend: :null,
          strategy: :fixed,
          fail_closed: RecordingStudioEmbeddable.configuration.rate_limit_fail_closed,
          prefix: "recording_studio_embeddable:rate",
          rescue_errors: [StandardError]
        )
      end

      def allow?(**)
        self.class.allow?(**)
      end
    end
  end
end
