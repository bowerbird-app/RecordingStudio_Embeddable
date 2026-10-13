# frozen_string_literal: true

module RecordingStudioEmbeddable
  # Stable bridge for the popup iframe. Not published to Artifacts.
  class WidgetBridgesController < ActionController::Base
    skip_forgery_protection

    SCRIPT = Engine.root.join("lib/recording_studio_embeddable/floating/widget_bridge.js")

    def show
      response.set_header("Cache-Control", "public, max-age=300")
      response.set_header("X-Content-Type-Options", "nosniff")
      render plain: SCRIPT.read, content_type: "text/javascript"
    end
  end
end
