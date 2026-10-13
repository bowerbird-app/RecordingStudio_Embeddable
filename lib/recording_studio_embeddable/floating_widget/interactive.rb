# frozen_string_literal: true

module RecordingStudioEmbeddable
  module FloatingWidget
    # Host popup controllers include this. It does not use the app session or current_user.
    module Interactive
      extend ActiveSupport::Concern

      included do
        protect_from_forgery with: :exception, store: CsrfCookieStore.new
        before_action :prepare_floating_widget!
        helper_method :recording_studio_widget_parent_origin, :recording_studio_widget_embed,
                      :recording_studio_widget_recording
      end

      # Avoid ActionController's session read, which would mint the host session cookie.
      def protect_against_forgery?
        allow_forgery_protection
      end

      def verified_request?
        request.get? || request.head? || !protect_against_forgery? ||
          (valid_request_origin? && widget_authenticity_token_valid?)
      end

      def recording_studio_widget_embed
        @recording_studio_widget_embed
      end

      def recording_studio_widget_recording
        @recording_studio_widget_recording
      end

      def recording_studio_widget_parent_origin
        @recording_studio_widget_parent_origin
      end

      private

      def widget_authenticity_token_valid?
        request_authenticity_tokens.any? { |token| valid_authenticity_token?(nil, token) }
      end

      def prepare_floating_widget!
        @recording_studio_widget_embed = Embed.find_by(token: params[:token].to_s)
        @recording_studio_widget_recording = @recording_studio_widget_embed&.parent_recording
        return head(:not_found) unless floating_widget_document?

        response.set_header("Cache-Control", "private, no-store")
        response.set_header("Content-Security-Policy", "frame-ancestors #{widget_frame_ancestors}")
        response.delete_header("X-Frame-Options")
        response.set_header("X-Content-Type-Options", "nosniff")
        @recording_studio_widget_parent_origin = resolved_parent_origin

        return if RequestRateLimit.allow?(key: "widget:#{params[:token]}:#{request.remote_ip}")

        response.set_header("Retry-After", RecordingStudioEmbeddable.configuration.rate_limit_window.to_i.to_s)
        head :too_many_requests
      end

      def floating_widget_document?
        embed = @recording_studio_widget_embed
        recording = @recording_studio_widget_recording
        embed&.floating_enabled? && recording.present? && Floating::Capability.for(recording).enabled?
      end

      def widget_frame_ancestors
        widget_domain_policy(parent_candidate.presence || request.base_url).frame_ancestors.join(" ")
      end

      def resolved_parent_origin
        candidate = parent_candidate
        return if candidate.blank?
        return unless widget_domain_policy(candidate).allowed?

        candidate
      end

      def parent_candidate
        Floating::Origin.echoable(request.headers["Origin"]) || referer_origin
      end

      def referer_origin
        return if request.referer.blank?

        uri = URI.parse(request.referer)
        return unless uri.is_a?(URI::HTTP) && uri.host.present?

        default_port = uri.scheme == "https" ? 443 : 80
        authority = uri.port == default_port ? uri.host.downcase : "#{uri.host.downcase}:#{uri.port}"
        Floating::Origin.echoable("#{uri.scheme}://#{authority}")
      rescue URI::InvalidURIError
        nil
      end

      def widget_domain_policy(origin)
        Security::DomainPolicy.new(
          embed: @recording_studio_widget_embed,
          origin: origin,
          referer: nil,
          request_host: request.host,
          options: Renderer.options_for(@recording_studio_widget_recording)
        )
      end
    end
  end
end
