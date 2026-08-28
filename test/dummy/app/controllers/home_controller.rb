class HomeController < ApplicationController
  def index
    @recordings = RecordingStudio::Recording.where(recordable_type: %w[Page Article Document])
      .includes(:recordable, :parent_recording)
      .order(:created_at, :id)
  end
end
