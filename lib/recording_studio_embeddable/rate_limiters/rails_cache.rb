# frozen_string_literal: true

module RecordingStudioEmbeddable
  module RateLimiters
    # Thin adapter over RecordingStudioCache::RateLimiter (:rails_cache backend).
    #
    # Preserves Embeddable config keys (+rate_limit+, +rate_limit_window+,
    # +rate_limit_fail_closed+) and the fixed-window key shape
    # +recording_studio_embeddable:rate:<key>:<bucket>+.
    #
    # Main always used +Rails.cache+ (no gem +cache_store+ / +config.cache+);
    # this adapter passes that same store explicitly.
    #
    # Shared RateLimiter treats +limit <= 0+ as disabled (always allow). Main
    # compared +count.to_i <= limit.to_i+, so non-positive / blank limits block.
    # Non-positive windows raised +ZeroDivisionError+ on main (rescued into
    # +rate_limit_fail_closed+); that outcome is preserved here.
    class RailsCache
      def self.allow?(key:, limit:, window:)
        # Same store main used — Rails.cache, not RecordingStudioCache.store.
        store = rails_cache_store
        return true unless store

        period = window.to_i
        return allow_on_failure? if period <= 0

        # After main's Rails.cache check (and window coercion): shared would
        # disable on limit<=0; main blocked via count <= limit.to_i.
        return false if limit.to_i <= 0

        RecordingStudioCache::RateLimiter.allow?(
          key: key,
          limit: limit.to_i,
          window: period,
          backend: :rails_cache,
          strategy: :fixed,
          store: store,
          fail_closed: fail_closed?,
          prefix: "recording_studio_embeddable:rate",
          rescue_errors: [StandardError]
        )
      rescue StandardError
        allow_on_failure?
      end

      def allow?(**)
        self.class.allow?(**)
      end

      def self.rails_cache_store
        return unless defined?(Rails) && Rails.respond_to?(:cache)

        Rails.cache
      end
      private_class_method :rails_cache_store

      def self.fail_closed?
        RecordingStudioEmbeddable.configuration.rate_limit_fail_closed
      end
      private_class_method :fail_closed?

      def self.allow_on_failure?
        !fail_closed?
      end
      private_class_method :allow_on_failure?
    end
  end
end
