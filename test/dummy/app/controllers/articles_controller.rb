class ArticlesController < ApplicationController
  def embed
    @article = Article.find(params[:id])
    render :embed, layout: false
  end
end
