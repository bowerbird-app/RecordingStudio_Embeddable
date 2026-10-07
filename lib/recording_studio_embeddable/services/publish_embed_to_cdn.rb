# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Services
    # Pre-renders an embed HTML document and publishes it via RecordingStudioArtifacts.
    #
    # First publish calls +RecordingStudioArtifacts.publish+; re-publish calls +.update+
    # so the Artifacts public URL stays stable. Spaces / EMBED_CDN upload is not used.
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

      CONTENT_TYPE = "text/html; charset=utf-8"

      def initialize(embed:, storage: nil, purger: nil, synchronous: true)
        super()
        @embed = embed
        @storage = storage
        @purger = purger
        @synchronous = synchronous
      end

      private

      attr_reader :embed, :synchronous

      def perform
        return failure("embed is required") if embed.blank?
        return failure("embed token is required") if embed.token.blank?
        return failure("embed is not on the CDN URL strategy") unless embed.cdn_url_strategy?
        return failure("RecordingStudioArtifacts is not available") unless Cdn.artifacts_available?
        return failure("Artifacts CDN public base URL is not configured") unless artifacts_public_base_configured?

        recording = embed.parent_recording
        options = Renderer.options_for(recording)
        available = publicly_available?(recording, options)
        frame_ancestors = resolve_frame_ancestors(options, available: available)
        html = render_html(recording, frame_ancestors, available: available)
        publish_result = publish_via_artifacts(html, frame_ancestors: frame_ancestors)
        return publish_result if publish_result.failure?

        public_url = publish_result.value[:public_url]
        artifact = publish_result.value[:artifact]
        mark_published!(artifact: artifact, public_url: public_url)

        success(
          artifact_id: artifact&.id || embed.artifact_id,
          public_url: public_url,
          frame_ancestors: frame_ancestors,
          available: available,
          enqueued: publish_result.value[:enqueued]
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

      def publish_via_artifacts(html, frame_ancestors:)
        args = {
          body: html,
          content_type: CONTENT_TYPE,
          source: {
            "gem" => "recording_studio_embeddable",
            "external_id" => embed.token
          },
          metadata: {
            "embed_token" => embed.token,
            "frame_ancestors" => Array(frame_ancestors)
          },
          synchronous: synchronous
        }
        args[:storage] = storage if storage
        args[:purger] = purger if purger

        artifact_id = embed.artifact_id
        if artifact_id.present?
          RecordingStudioArtifacts.update(id: artifact_id, **args)
        else
          RecordingStudioArtifacts.publish(format: "html", **args)
        end
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
        @storage ||= RecordingStudioEmbeddable.configuration.cdn_storage
      end

      def purger
        @purger ||= RecordingStudioEmbeddable.configuration.cdn_purger
      end

      def artifacts_public_base_configured?
        return false unless defined?(RecordingStudioArtifacts::Cdn)

        RecordingStudioArtifacts::Cdn.public_base_configured?
      end

      def mark_published!(artifact:, public_url:)
        return unless embed.respond_to?(:mark_cdn_published!)

        embed.mark_cdn_published!(
          artifact_id: artifact&.id,
          public_url: public_url,
          object_key: artifact&.try(:object_key),
          etag: artifact&.try(:etag)
        )
      end

      def service_args
        { embed_id: embed&.id, token: embed&.token, synchronous: synchronous }
      end
    end # rubocop:enable Metrics/ClassLength
  end
end
