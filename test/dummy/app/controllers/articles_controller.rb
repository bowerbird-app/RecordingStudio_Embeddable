class ArticlesController < ApplicationController
  def show
    @article = @parent_recordable || Article.find(params[:id])
  end

  def embed
    @article = @parent_recordable || Article.find(params[:id])
    render :embed, layout: false
  end
end
