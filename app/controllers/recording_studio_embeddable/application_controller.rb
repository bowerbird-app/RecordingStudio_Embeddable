# frozen_string_literal: true

module RecordingStudioEmbeddable
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout "recording_studio_embeddable/application"
    helper RecordingStudioEmbeddable::EmbedLayoutHelper
  end
end
