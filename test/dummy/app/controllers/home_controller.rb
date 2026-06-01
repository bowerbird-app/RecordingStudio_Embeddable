class HomeController < ApplicationController
  before_action :load_edit_button_component, if: :publishable_available?

  def index
    @recordings = RecordingStudio::Recording.where(recordable_type: %w[Page Article Document])
      .includes(:recordable, :parent_recording)
      .order(:created_at, :id)
  end

  private

  def publishable_available?
    defined?(RecordingStudioPublishable::Engine)
  end

  def load_edit_button_component
    require_dependency RecordingStudioPublishable::Engine.root.join("app/components/recording_studio_publishable/edit_button_component").to_s
  end
end
