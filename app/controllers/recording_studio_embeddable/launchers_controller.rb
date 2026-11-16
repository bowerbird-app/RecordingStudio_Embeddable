# frozen_string_literal: true

module RecordingStudioEmbeddable
  # Public launcher config. CORS echoes an allowlisted Origin and never "*".
  # Missing Origin fails closed. This response is not the embed document and
  # is not published to Artifacts.
  class LaunchersController < ActionController::Base
    include PublicRequestLimits

    def show
      return head(:forbidden) if echoed_origin.nil?

      enforce_ip_limit
      return if performed?

      enforce_miss_limit
      return if performed?

      return render_rate_limited unless RequestRateLimit.allow?(key: rate_limit_key)
      return not_found_after_miss unless public_embed?
      return head(:forbidden) unless origin_allowed?

      payload = Floating::LauncherConfig.call(embed: @embed, recording: @recording, request: request)
      return not_found_after_miss if payload.nil?

      apply_cors!(echoed_origin)
      response.set_header("Cache-Control", "private, no-store")
      response.set_header("X-Content-Type-Options", "nosniff")
      render json: payload
    end

    def preflight
      return head(:forbidden) if echoed_origin.nil?

      enforce_ip_limit
      return if performed?

      enforce_miss_limit
      return if performed?

      return render_rate_limited unless RequestRateLimit.allow?(key: rate_limit_key)
      return not_found_after_miss unless public_embed?
      return head(:forbidden) unless origin_allowed?

      apply_cors!(echoed_origin)
      response.set_header("Cache-Control", "private, no-store")
      head :no_content
    end

    private

    def rate_limit_key
      "launcher:#{params[:token]}:#{request.remote_ip}"
    end

    def public_embed?
      @embed = Embed.find_by(token: params[:token].to_s)
      @recording = @embed&.parent_recording
      Floating::PublicDocument.available?(embed: @embed, recording: @recording, request: request)
    end

    def echoed_origin
      return @echoed_origin if defined?(@echoed_origin)

      @echoed_origin = Floating::Origin.echoable(request.headers["Origin"])
    end

    def origin_allowed?
      return false unless @embed && echoed_origin

      domain_policy.allowed?
    end

    def domain_policy
      @domain_policy ||= Security::DomainPolicy.new(
        embed: @embed,
        origin: echoed_origin,
        referer: nil,
        request_host: request.host,
        options: Renderer.options_for(@recording)
      )
    end

    def apply_cors!(origin)
      response.set_header("Access-Control-Allow-Origin", origin)
      response.set_header("Vary", "Origin")
      response.set_header("Access-Control-Allow-Methods", "GET, OPTIONS")
      response.set_header("Access-Control-Allow-Headers", "Accept")
      response.headers.delete("Access-Control-Allow-Credentials")
    end

    def render_rate_limited(window: RecordingStudioEmbeddable.configuration.rate_limit_window)
      apply_cors!(echoed_origin)
      response.set_header("Cache-Control", "private, no-store")
      response.set_header("Retry-After", window.to_i.to_s)
      head :too_many_requests
    end
  end
end
