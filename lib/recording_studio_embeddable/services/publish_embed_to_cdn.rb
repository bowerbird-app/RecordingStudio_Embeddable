# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Services
    # Pre-renders an embed HTML document to DigitalOcean Spaces and purges Cloudflare.
    #
    # Always writes the same object key (`embeds/{token}.html`) so partner URLs stay stable.
    # Bakes DomainPolicy frame-ancestors at publish time (static files cannot vary CSP by Referer).
    class PublishEmbedToCdn < BaseService # rubocop:disable Metrics/ClassLength
      UNAVAILABLE_HTML = <<~HTML
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="robots" content="noindex, nofollow">
            <title>Embed unavailable</title>
          </head>
          <body>
            <p>This embed is not available.</p>
          </body>
        </html>
      HTML

      def initialize(embed:, storage: nil, purger: nil)
        super()
        @embed = embed
        @storage = storage
        @purger = purger
      end

      private

      attr_reader :embed

      def perform
        return failure("embed is required") if embed.blank?
        return failure("embed token is required") if embed.token.blank?
        return failure("embed is not on the CDN URL strategy") unless embed.cdn_url_strategy?
        return failure("CDN public base URL is not configured") unless Cdn.public_base_configured?

        recording = embed.parent_recording
        options = Renderer.options_for(recording)
        available = publicly_available?(recording, options)
        frame_ancestors = resolve_frame_ancestors(options, available: available)
        html = render_html(recording, frame_ancestors, available: available)
        key = embed.cdn_object_key
        put_result = upload(key, html, frame_ancestors)
        public_url = Cdn.public_url(embed.token)
        purge_result = purge(public_url)
        mark_published!(key: key, etag: put_result[:etag], public_url: public_url)

        success(
          key: key,
          public_url: public_url,
          etag: put_result[:etag],
          frame_ancestors: frame_ancestors,
          purged: purge_result[:purged],
          available: available
        )
      rescue StandardError => e
        failure(e)
      end

      def resolve_frame_ancestors(options, available:)
        return ["'none'"] unless available

        Security::DomainPolicy.new(embed: embed, options: options).frame_ancestors
      end

      def render_html(recording, frame_ancestors, available:)
        return inject_unavailable_csp(UNAVAILABLE_HTML, frame_ancestors: frame_ancestors) unless available

        result = RenderEmbedDocument.call(
          recording: recording,
          embed: embed,
          frame_ancestors: frame_ancestors
        )
        return result.value! if result.success?

        raise result.error
      end

      def upload(key, html, frame_ancestors)
        storage.put_object(
          key: key,
          body: html,
          content_type: "text/html; charset=utf-8",
          cache_control: Cdn.cache_control,
          metadata: {
            "content-security-policy" => "frame-ancestors #{frame_ancestors.join(' ')}",
            "embed-token" => embed.token.to_s
          }
        )
      end

      def publicly_available?(recording, options)
        return false unless RecordingStudioEmbeddable.configuration.public_embeds_enabled
        return false unless embed.enabled?
        return false if recording.blank?
        return false unless options[:enabled] == true

        publishable_allowed?(recording, options)
      end

      def publishable_allowed?(recording, options)
        required = options.fetch(:require_publishable, RecordingStudioEmbeddable.configuration.require_publishable)
        return true unless required

        return !!recording.currently_published? if recording.respond_to?(:currently_published?)
        return !!recording.current_publishable if recording.respond_to?(:current_publishable)
        return !!recording.publishable_child_recording if recording.respond_to?(:publishable_child_recording)

        false
      end

      def inject_unavailable_csp(html, frame_ancestors:)
        csp = "frame-ancestors #{Array(frame_ancestors).join(' ')}"
        marker = "<!-- recording-studio-embeddable-csp: #{csp} -->\n" \
                 "<meta http-equiv=\"Content-Security-Policy\" content=\"#{csp}\">\n"
        html.sub("<head>", "<head>\n#{marker}")
      end

      def storage
        @storage ||= RecordingStudioEmbeddable.configuration.cdn_storage || default_storage
      end

      def default_storage
        return Cdn::SpacesClient.new if Cdn::Credentials.spaces_configured?

        raise ArgumentError,
              "CDN Spaces credentials are not configured. Set EMBED_CDN_SPACES_* env vars " \
              "or Rails credentials under recording_studio_embeddable.cdn, " \
              "or assign config.cdn_storage for tests."
      end

      def purger
        @purger ||= RecordingStudioEmbeddable.configuration.cdn_purger || default_purger
      end

      def default_purger
        return Cdn::CloudflarePurge.new if Cdn::Credentials.cloudflare_purge_configured?

        nil
      end

      def purge(public_url)
        return { purged: [] } if purger.nil? || public_url.blank?

        purger.purge_urls([public_url])
      end

      def mark_published!(key:, etag:, public_url:)
        return unless embed.respond_to?(:mark_cdn_published!)

        embed.mark_cdn_published!(key: key, etag: etag, public_url: public_url)
      end

      def service_args
        { embed_id: embed&.id, token: embed&.token }
      end
    end
  end
end
