# frozen_string_literal: true

module RecordingStudioEmbeddable
  # Stable, non-fingerprinted classic script. Partners paste this URL.
  class WidgetScriptsController < ActionController::Base
    # Cross-origin <script src> must not be blocked by Rails' same-origin JS check.
    skip_forgery_protection

    SCRIPT = Engine.root.join("lib/recording_studio_embeddable/floating/widget.js")

    def show
      response.set_header("Cache-Control", "public, max-age=300")
      response.set_header("X-Content-Type-Options", "nosniff")
      render plain: SCRIPT.read, content_type: "text/javascript"
    end
  end
end
