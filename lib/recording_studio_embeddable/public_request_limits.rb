# frozen_string_literal: true

module RecordingStudioEmbeddable
  # Shared per-IP and invalid-token miss gate from the public embed.
  # Hosts render their own 429 through +render_rate_limited+.
  module PublicRequestLimits
    private

    def enforce_ip_limit
      return if RequestRateLimit.public_ip_allowed?(request.remote_ip)

      render_rate_limited(window: RecordingStudioEmbeddable.configuration.per_ip_rate_limit_window)
    end

    def enforce_miss_limit
      return unless RequestRateLimit.public_miss_blocked?(request.remote_ip)

      render_rate_limited(window: RecordingStudioEmbeddable.configuration.invalid_token_rate_limit_window)
    end

    def record_token_miss
      return if RequestRateLimit.record_public_miss(request.remote_ip)

      render_rate_limited(window: RecordingStudioEmbeddable.configuration.invalid_token_rate_limit_window)
    end

    def not_found_after_miss
      record_token_miss
      return if performed?

      head(:not_found)
    end
  end
end
