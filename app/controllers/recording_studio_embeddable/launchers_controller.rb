# frozen_string_literal: true

module RecordingStudioEmbeddable
  # Public launcher config. CORS echoes an allowlisted Origin and never "*".
  # Missing Origin fails closed. This response is not the embed document and
  # is not published to Artifacts.
  class LaunchersController < ActionController::Base
    def show
      return head(:forbidden) if echoed_origin.nil?
      return head(:not_found) unless floating_embed?
      return head(:forbidden) unless origin_allowed?
      return render_rate_limited unless RequestRateLimit.allow?(key: "launcher:#{params[:token]}:#{request.remote_ip}")

      payload = Floating::LauncherConfig.call(embed: @embed, recording: @recording, request: request)
      return head(:not_found) if payload.nil?

      apply_cors!(echoed_origin)
      response.set_header("Cache-Control", "private, no-store")
      response.set_header("X-Content-Type-Options", "nosniff")
      render json: payload
    end

    def preflight
      return head(:forbidden) if echoed_origin.nil?
      return head(:not_found) unless floating_embed?
      return head(:forbidden) unless origin_allowed?

      apply_cors!(echoed_origin)
      response.set_header("Cache-Control", "private, no-store")
      head :no_content
    end

    private

    def floating_embed?
      @embed = Embed.find_by(token: params[:token].to_s)
      @recording = @embed&.parent_recording
      @embed&.floating_enabled? && @recording.present? && Floating::Capability.for(@recording).enabled?
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

    def render_rate_limited
      apply_cors!(echoed_origin)
      response.set_header("Cache-Control", "private, no-store")
      response.set_header("Retry-After", RecordingStudioEmbeddable.configuration.rate_limit_window.to_i.to_s)
      head :too_many_requests
    end
  end
end
