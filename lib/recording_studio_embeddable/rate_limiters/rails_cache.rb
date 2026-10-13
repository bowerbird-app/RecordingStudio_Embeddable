# frozen_string_literal: true

module RecordingStudioEmbeddable
  module RateLimiters
    # Thin adapter over RecordingStudioCache::RateLimiter (:rails_cache backend).
    #
    # Preserves Embeddable config keys (+rate_limit+, +rate_limit_window+,
    # +rate_limit_fail_closed+) and the fixed-window key shape
    # +recording_studio_embeddable:rate:<key>:<bucket>+.
    class RailsCache
      def self.allow?(key:, limit:, window:)
        RecordingStudioCache::RateLimiter.allow?(
          key: key,
          limit: limit,
          window: window,
          backend: :rails_cache,
          strategy: :fixed,
          store: Rails.cache,
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
