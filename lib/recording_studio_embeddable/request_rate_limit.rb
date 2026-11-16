# frozen_string_literal: true

module RecordingStudioEmbeddable
  # Public embed buckets. Per-IP and per-token keys are digests, never the raw token.
  module RequestRateLimit
    PUBLIC_IP_PREFIX = "public-ip"
    PUBLIC_MISS_PREFIX = "public-ip-miss"
    MISS_BLOCK_PREFIX = "recording_studio_embeddable:public-ip-miss-block"

    module_function

    def allow?(key:, limit: nil, window: nil)
      return true unless enabled?

      limiter.allow?(
        key: Services::LogView.digest(key.to_s),
        limit: limit || configuration.rate_limit,
        window: window || configuration.rate_limit_window
      )
    end

    def public_ip_allowed?(ip)
      return true unless enabled?

      limiter.allow?(
        key: prefixed_digest(PUBLIC_IP_PREFIX, ip),
        limit: configuration.per_ip_rate_limit,
        window: configuration.per_ip_rate_limit_window
      )
    end

    def public_miss_blocked?(ip)
      return false unless enabled?
      return false if null_limiter?

      limit = configuration.invalid_token_rate_limit.to_i
      return true if limit <= 0

      key = miss_key(ip)
      read_count(key, configuration.invalid_token_rate_limit_window).to_i >= limit || miss_block_marker?(key)
    rescue StandardError
      configuration.rate_limit_fail_closed
    end

    def record_public_miss(ip)
      return true unless enabled?

      key = miss_key(ip)
      allowed = limiter.allow?(
        key: key,
        limit: configuration.invalid_token_rate_limit,
        window: configuration.invalid_token_rate_limit_window
      )
      remember_miss_block!(key) unless allowed
      allowed
    end

    def public_token_allowed?(token, ip)
      return true unless enabled?

      limiter.allow?(
        key: Services::LogView.digest("#{token}:#{ip}"),
        limit: configuration.rate_limit,
        window: configuration.rate_limit_window
      )
    end

    def limiter_for(configured)
      return RateLimiters::Redis if configured.respond_to?(:incr)
      return configured if configured.respond_to?(:allow?)

      case configured
      when :rails_cache then RateLimiters::RailsCache
      when :redis then RateLimiters::Redis
      else RateLimiters::Null
      end
    end

    def limiter
      limiter_for(configuration.rate_limiter)
    end

    def configuration
      RecordingStudioEmbeddable.configuration
    end

    def enabled?
      configuration.rate_limiting_enabled
    end

    def null_limiter?
      current = limiter
      current == RateLimiters::Null || current.is_a?(RateLimiters::Null)
    end

    def miss_key(ip)
      prefixed_digest(PUBLIC_MISS_PREFIX, ip)
    end

    def prefixed_digest(prefix, material)
      "#{prefix}:#{Services::LogView.digest(material.to_s)}"
    end

    def read_count(key, window)
      current = limiter
      return current.count(key:, window:) if current.respond_to?(:count)

      0
    end

    def remember_miss_block!(key)
      window = configuration.invalid_token_rate_limit_window.to_i
      return if window <= 0 || !cache_store

      cache_store.write("#{MISS_BLOCK_PREFIX}:#{key}", 1, expires_in: window)
    rescue StandardError
      nil
    end

    def miss_block_marker?(key)
      return false unless cache_store

      cache_store.read("#{MISS_BLOCK_PREFIX}:#{key}").present?
    rescue StandardError
      configuration.rate_limit_fail_closed
    end

    def cache_store
      Rails.cache if defined?(Rails) && Rails.respond_to?(:cache)
    end
  end
end
