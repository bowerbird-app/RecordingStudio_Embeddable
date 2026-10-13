# frozen_string_literal: true

module RecordingStudioEmbeddable
  module RequestRateLimit
    module_function

    def allow?(key:)
      return true unless RecordingStudioEmbeddable.configuration.rate_limiting_enabled

      limiter_for(RecordingStudioEmbeddable.configuration.rate_limiter).allow?(
        key: Services::LogView.digest(key.to_s),
        limit: RecordingStudioEmbeddable.configuration.rate_limit,
        window: RecordingStudioEmbeddable.configuration.rate_limit_window
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
  end
end
