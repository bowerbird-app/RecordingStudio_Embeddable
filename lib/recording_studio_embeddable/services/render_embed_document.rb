# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Services
    # Renders the full iframe HTML document (layout + body) for CDN publish.
    class RenderEmbedDocument < BaseService
      def initialize(recording:, embed:, frame_ancestors: nil, assigns: nil)
        super()
        @recording = recording
        @embed = embed
        @frame_ancestors = frame_ancestors
        @assigns = assigns || {}
      end

      private

      attr_reader :recording, :embed, :frame_ancestors, :assigns

      def perform
        return failure("recording is required") if recording.blank?
        return failure("embed is required") if embed.nil?

        template = Renderer.resolve(recording, embed)
        layout = Renderer.layout_for(recording, embed)
        theme = Renderer.embed_theme_for(recording, embed: embed)
        html = renderer.render(
          template: template,
          layout: layout,
          formats: [:html],
          assigns: document_assigns(theme)
        )
        success(inject_frame_ancestors(html))
      rescue StandardError => e
        failure(e)
      end

      def document_assigns(theme)
        recordable = recording.respond_to?(:recordable) ? recording.recordable : nil
        base = {
          parent_recording: recording,
          recording: recording,
          parent_recordable: recordable,
          recordable: recordable,
          embed: embed,
          embed_theme: theme
        }
        base[recordable.model_name.element.to_sym] = recordable if recordable.respond_to?(:model_name)
        base.merge(assigns.transform_keys(&:to_sym))
      end

      def inject_frame_ancestors(html)
        ancestors = Array(frame_ancestors).presence || ["'none'"]
        csp = "frame-ancestors #{ancestors.join(' ')}"
        marker = "<!-- recording-studio-embeddable-csp: #{csp} -->\n" \
                 "<meta http-equiv=\"Content-Security-Policy\" content=\"#{csp}\">\n"
        if html.include?("<head>")
          html.sub("<head>", "<head>\n#{marker}")
        else
          "#{marker}#{html}"
        end
      end

      def renderer
        if defined?(::ApplicationController) && ::ApplicationController.respond_to?(:renderer)
          ::ApplicationController.renderer
        else
          require "action_controller" unless defined?(ActionController::Base)
          ActionController::Base.renderer
        end
      end

      def service_args
        { recording: recording, embed: embed, frame_ancestors: frame_ancestors }
      end
    end
  end
end
