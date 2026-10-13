# frozen_string_literal: true

# Popup document for the floating launcher. Interactive, and not the host session.
class WidgetPopupsController < ActionController::Base
  include RecordingStudioEmbeddable::FloatingWidget::Interactive

  layout "widget_popup"

  def show
    @widget = recording_studio_widget_recording.recordable
  end

  def create
    @widget = recording_studio_widget_recording.recordable
    @inquiry = WidgetInquiry.new(inquiry_params.merge(widget_token: params[:token]))
    if @inquiry.save
      render :thanks
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def inquiry_params
    params.require(:inquiry).permit(:name, :email, :message)
  end
end
