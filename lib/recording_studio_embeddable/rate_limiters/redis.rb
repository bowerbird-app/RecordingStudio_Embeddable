# frozen_string_literal: true

module RecordingStudioEmbeddable
  module RateLimiters
    class Redis
      def self.allow?(key:, limit:, window:)
        redis = RecordingStudioEmbeddable.configuration.redis
        if RecordingStudioEmbeddable.configuration.rate_limiter.respond_to?(:incr)
          redis ||= RecordingStudioEmbeddable.configuration.rate_limiter
        end
        return true unless redis.respond_to?(:incr)

        cache_key = "recording_studio_embeddable:rate:#{key}:#{Time.current.to_i / window.to_i}"
        count = redis.incr(cache_key)
        redis.expire(cache_key, window.to_i) if redis.respond_to?(:expire)
        count.to_i <= limit.to_i
      rescue StandardError
        !RecordingStudioEmbeddable.configuration.rate_limit_fail_closed
      end

      def allow?(**)
        self.class.allow?(**)
      end
    end
  end
end
