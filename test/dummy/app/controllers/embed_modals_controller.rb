# frozen_string_literal: true

class EmbedModalsController < ApplicationController
  def show
    page = Page.find_by(title: "Getting Started")
    widget = Widget.find_by(title: "Hello")
    @page_recording = RecordingStudio::Recording.unscoped.find_by(recordable: page) if page
    @widget_recording = RecordingStudio::Recording.unscoped.find_by(recordable: widget) if widget
  end
end
