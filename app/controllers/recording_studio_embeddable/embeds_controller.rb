# frozen_string_literal: true

module RecordingStudioEmbeddable
  class EmbedsController < ActionController::Base
    layout "recording_studio_embeddable/iframe"

    before_action :load_embed

    def show
      return render_rate_limited if rate_limited?

      unless @embed
        capture_public_view(nil, "invalid_token", 404, metadata: { reason: "invalid_token" })
        return render_not_found
      end

      @recording = @embed.recording
      @parent_recording = @recording&.parent_recording if @recording.respond_to?(:parent_recording)
      @parent_recordable = @parent_recording&.recordable if @parent_recording.respond_to?(:recordable)
      @recordable = @parent_recordable
      assign_recordable_instance_variable
      @options = Renderer.options_for(@parent_recording)
      access = Security::PublicAccess.call(embed: @embed, request: request, recording: @parent_recording,
                                           options: @options)
      return render_denied(access) unless access.allowed?

      set_security_headers(access.domain_policy)
      set_public_cache_headers
      unless stale?(etag: cache_key_parts, last_modified: last_modified_at, public: true)
        capture_public_view(@embed, "not_modified", 304, cache_hit: true)
        return
      end

      capture_public_view(@embed, "rendered", 200)
      render Renderer.resolve(@parent_recording, @embed), formats: [:html]
    end

    private

    def load_embed
      @embed = Embed.find_by(token: params[:token].to_s)
    end

    def rate_limited?
      return false unless RecordingStudioEmbeddable.configuration.rate_limiting_enabled

      configured = RecordingStudioEmbeddable.configuration.rate_limiter
      limiter = if configured.respond_to?(:allow?)
                  configured
                else
                  case configured
                  when :rails_cache then RateLimiters::RailsCache
                  when :redis then RateLimiters::Redis
                  else RateLimiters::Null
                  end
                end
      limiter = RateLimiters::Redis if configured.respond_to?(:incr)
      !limiter.allow?(
        key: Services::LogView.digest("#{params[:token]}:#{request.remote_ip}"),
        limit: RecordingStudioEmbeddable.configuration.rate_limit,
        window: RecordingStudioEmbeddable.configuration.rate_limit_window
      )
    end

    def set_security_headers(domain_policy)
      response.set_header("Content-Security-Policy", "frame-ancestors #{domain_policy.frame_ancestors.join(' ')}")
      response.set_header("X-Content-Type-Options", "nosniff")
      response.set_header("Referrer-Policy", "strict-origin-when-cross-origin")
      response.set_header("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=()")
      response.set_header("Vary", "Origin, Referer")
      response.delete_header("X-Frame-Options")
    end

    def set_public_cache_headers
      policy = CachePolicy.resolve(embed: @embed, recording: @parent_recording)
      response.cache_control.replace(
        public: policy[:public],
        max_age: policy[:max_age],
        stale_while_revalidate: policy[:stale_while_revalidate]
      )
    end

    def last_modified_at
      [@embed&.updated_at, @parent_recording&.updated_at,
       @parent_recordable.try(:updated_at)].compact.max || Time.current
    end

    def render_denied(access)
      response.cache_control.replace(no_store: true)
      set_security_headers(access.domain_policy)
      status = access.reason == :unpublished ? "unpublished" : access.status.to_s
      capture_public_view(@embed, status, Rack::Utils.status_code(access.status), metadata: { reason: access.reason })
      access.status == :not_found ? render_not_found : head(access.status)
    end

    def render_not_found
      response.cache_control.replace(no_store: true)
      response.set_header("Content-Security-Policy", "frame-ancestors 'none'")
      head :not_found
    end

    def render_rate_limited
      response.cache_control.replace(no_store: true)
      response.set_header("Retry-After", RecordingStudioEmbeddable.configuration.rate_limit_window.to_i.to_s)
      capture_public_view(@embed, "rate_limited", 429, rate_limited: true)
      head :too_many_requests
    end

    def cache_key_parts
      [
        @embed,
        @parent_recording,
        @parent_recordable,
        @options,
        RecordingStudioEmbeddable.configuration.cache_mode,
        RecordingStudioEmbeddable.configuration.public_embed_cache_control
      ]
    end

    def capture_public_view(embed, status, status_code, cache_hit: false, rate_limited: false, metadata: {})
      Services::CaptureView.call(embed: embed, request: request, status: status, status_code: status_code,
                                 cache_hit: cache_hit, rate_limited: rate_limited, metadata: metadata)
    end

    def assign_recordable_instance_variable
      return unless @parent_recordable.respond_to?(:model_name)

      instance_variable_set(:"@#{@parent_recordable.model_name.element}", @parent_recordable)
    end
  end
end
