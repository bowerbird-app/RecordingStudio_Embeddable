# frozen_string_literal: true

module RecordingStudioEmbeddable
  module RateLimiters
    class RailsCache
      def self.allow?(key:, limit:, window:)
        return true unless defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache

        cache_key = "recording_studio_embeddable:rate:#{key}:#{Time.current.to_i / window.to_i}"
        count = Rails.cache.increment(cache_key, 1, expires_in: window.to_i.seconds)
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
