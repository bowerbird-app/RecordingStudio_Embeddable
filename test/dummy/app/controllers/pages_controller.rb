class PagesController < ApplicationController
  def show
    @page = @parent_recordable || Page.find(params[:id])
  end

  def embed
    @page = @parent_recordable || Page.find(params[:id])
    @parent_recording ||= RecordingStudio::Recording.unscoped.find_by(recordable: @page)
    @parent_recordable ||= @page
    render :embed, layout: false
  end
end
