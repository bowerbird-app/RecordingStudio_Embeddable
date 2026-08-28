# frozen_string_literal: true

module RecordingStudioEmbeddable
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    include RecordingStudio::UsesDefaultLayout

    # Re-assert after include: if the host already included UsesDefaultLayout, the
    # concern's `included` hook will not run again and a parent layout proc wins.
    layout "recording_studio/default_layout"

    protect_from_forgery with: :exception
    helper RecordingStudioEmbeddable::EmbedLayoutHelper
  end
end
