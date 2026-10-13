# frozen_string_literal: true

module RecordingStudioEmbeddable
  module RateLimiters
    # Thin adapter over RecordingStudioCache::RateLimiter (:redis backend).
    #
    # Resolves the Redis client from +configuration.redis+, or from
    # +configuration.rate_limiter+ when that object responds to +incr+ (legacy
    # host wiring). The shared limiter requires +eval+; clients that only
    # implement +incr+ raise +ArgumentError+.
    #
    # Shared RateLimiter treats +limit <= 0+ as disabled (always allow). Main
    # compared +count.to_i <= limit.to_i+, so non-positive / blank limits block.
    # Non-positive windows raised +ZeroDivisionError+ on main (rescued into
    # +rate_limit_fail_closed+); that outcome is preserved here.
    class Redis
      def self.allow?(key:, limit:, window:)
        redis = redis_client
        return true unless redis.respond_to?(:incr)

        period = window.to_i
        return allow_on_failure? if period <= 0

        # After main's redis.respond_to?(:incr) check (and window coercion):
        # shared would disable on limit<=0; main blocked via count <= limit.to_i.
        return false if limit.to_i <= 0

        RecordingStudioCache::RateLimiter.allow?(
          key: key,
          limit: limit.to_i,
          window: period,
          backend: :redis,
          strategy: :fixed,
          redis: redis,
          fail_closed: fail_closed?,
          prefix: "recording_studio_embeddable:rate",
          rescue_errors: [StandardError]
        )
      rescue ArgumentError => e
        raise if eval_required_error?(e)

        allow_on_failure?
      rescue StandardError
        allow_on_failure?
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

      def self.fail_closed?
        RecordingStudioEmbeddable.configuration.rate_limit_fail_closed
      end
      private_class_method :fail_closed?

      def self.allow_on_failure?
        !fail_closed?
      end
      private_class_method :allow_on_failure?

      def self.eval_required_error?(error)
        error.message.include?("responds to eval")
      end
      private_class_method :eval_required_error?
    end
  end
end
