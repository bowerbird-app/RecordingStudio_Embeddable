# frozen_string_literal: true

module RecordingStudioEmbeddable
  class EmbedsController < ActionController::Base
    include PublicRequestLimits

    layout "recording_studio_embeddable/embed"
    helper RecordingStudioEmbeddable::EmbedLayoutHelper

    def show
      enforce_ip_limit
      return if performed?

      enforce_miss_limit
      return if performed?

      @embed = Embed.find_by(token: embed_token)
      enforce_token_limit
      return if performed?

      unless @embed
        record_token_miss
        return if performed?

        log_rejected_public_embed("invalid_token")
        return render_not_found
      end

      @recording = @embed.recording
      @parent_recording = @recording&.parent_recording if @recording.respond_to?(:parent_recording)
      @parent_recordable = @parent_recording&.recordable if @parent_recording.respond_to?(:recordable)
      @recordable = @parent_recordable
      @options = Renderer.options_for(@parent_recording)
      access = Security::PublicAccess.call(embed: @embed, request: request, recording: @parent_recording,
                                           options: @options)
      return render_denied(access) unless access.allowed?

      assign_recordable_instance_variable

      set_security_headers(access.domain_policy)
      if cache_policy[:enabled]
        set_public_cache_headers
        unless stale?(etag: cache_key_parts, last_modified: last_modified_at, public: true)
          capture_public_view(@embed, "not_modified", 304, cache_hit: true)
          return
        end
      else
        response.cache_control.replace(no_store: true)
      end

      capture_public_view(@embed, "rendered", 200)
      @embed_theme = Renderer.embed_theme_for(@parent_recording, embed: @embed)
      render Renderer.resolve(@parent_recording, @embed),
             formats: [:html],
             layout: Renderer.layout_for(@parent_recording, @embed)
    end

    private

    def embed_token
      params[:token].to_s
    end

    def enforce_token_limit
      return if RequestRateLimit.public_token_allowed?(embed_token, request.remote_ip)

      render_rate_limited(window: embed_configuration.rate_limit_window)
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
      response.cache_control.replace(
        public: cache_policy[:public],
        max_age: cache_policy[:max_age],
        stale_while_revalidate: cache_policy[:stale_while_revalidate]
      )
    end

    def cache_policy
      @cache_policy ||= CachePolicy.resolve(embed: @embed, recording: @parent_recording)
    end

    def last_modified_at
      [@embed&.updated_at, @parent_recording&.updated_at,
       @parent_recordable.try(:updated_at)].compact.max || Time.current
    end

    def render_denied(access)
      if access.status == :not_found
        record_token_miss
        return if performed?

        log_rejected_public_embed("not_found")
        return render_not_found
      end

      record_token_miss
      return if performed?

      response.cache_control.replace(no_store: true)
      set_security_headers(access.domain_policy)
      capture_public_view(@embed, access.status.to_s, Rack::Utils.status_code(access.status),
                          metadata: { reason: access.reason })
      head(access.status)
    end

    def render_not_found
      clear_embed_render_state
      response.cache_control.replace(no_store: true)
      response.set_header("Content-Security-Policy", "frame-ancestors 'none'")
      response.delete_header("X-Frame-Options")
      render template: "recording_studio_embeddable/embeds/not_found",
             formats: [:html],
             layout: "recording_studio_embeddable/embed",
             status: :not_found
    end

    def render_rate_limited(window: embed_configuration.rate_limit_window)
      response.cache_control.replace(no_store: true)
      response.set_header("Retry-After", window.to_i.to_s)
      log_rejected_public_embed("rate_limited")
      head :too_many_requests
    end

    def clear_embed_render_state
      @embed = nil
      @embed_theme = nil
      @recording = nil
      @parent_recording = nil
      @parent_recordable = nil
      @recordable = nil
    end

    def log_rejected_public_embed(reason)
      sample = embed_configuration.invalid_token_log_sample_rate.to_f
      return if sample <= 0
      return if sample < 1.0 && Kernel.rand >= sample
      return unless defined?(Rails) && Rails.logger

      ip_digest = Services::LogView.digest(request.remote_ip)
      Rails.logger.info(
        "[RecordingStudioEmbeddable] public embed rejected reason=#{reason} ip_digest=#{ip_digest}"
      )
    end

    def embed_configuration
      RecordingStudioEmbeddable.configuration
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
