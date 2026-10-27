# frozen_string_literal: true

module RecordingStudioEmbeddable
  class ApplicationController < (defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base)
    recording_studio_layout { RecordingStudioEmbeddable.configuration.layout }

    protect_from_forgery with: :exception
    helper RecordingStudioEmbeddable::EmbedLayoutHelper
  end
end
