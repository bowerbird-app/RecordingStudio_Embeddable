# frozen_string_literal: true

module RecordingStudioEmbeddable
  module RateLimiters
    # Thin adapter over RecordingStudioCache::RateLimiter (:redis backend).
    #
    # Resolves the Redis client from +configuration.redis+, or from
    # +configuration.rate_limiter+ when that object responds to +incr+ (legacy
    # host wiring). The shared limiter requires +eval+; clients that only
    # implement +incr+ raise +ArgumentError+.
    class Redis
      def self.allow?(key:, limit:, window:)
        RecordingStudioCache::RateLimiter.allow?(
          key: key,
          limit: limit,
          window: window,
          backend: :redis,
          strategy: :fixed,
          redis: redis_client,
          fail_closed: RecordingStudioEmbeddable.configuration.rate_limit_fail_closed,
          prefix: "recording_studio_embeddable:rate",
          rescue_errors: [StandardError]
        )
      end

      def allow?(**)
        self.class.allow?(**)
      end

      def self.redis_client
        redis = RecordingStudioEmbeddable.configuration.redis
        if RecordingStudioEmbeddable.configuration.rate_limiter.respond_to?(:incr)
          redis ||= RecordingStudioEmbeddable.configuration.rate_limiter
        end
        redis
      end
      private_class_method :redis_client
    end
  end
end
