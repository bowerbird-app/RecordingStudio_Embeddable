class ArticlesController < ApplicationController
  def show
    @article = @parent_recordable || Article.find(params[:id])
  end

  def embed
    @article = @parent_recordable || Article.find(params[:id])
    @parent_recording ||= RecordingStudio::Recording.unscoped.find_by(recordable: @article)
    @parent_recordable ||= @article
    render :embed, layout: false
  end
end
