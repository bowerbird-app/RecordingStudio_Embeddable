# frozen_string_literal: true

class DummyArticlesController < ApplicationController
  def edit
    @article = Article.find(params[:id])
  end

  def update
    article = Article.find(params[:id])
    article.update!(
      title: article_title_param.presence || article.title,
      description: article_description_param
    )

    redirect_to root_path, notice: "Updated #{article.title}"
  end

  private

  def article_title_param
    params.fetch(:title, "").to_s.strip
  end

  def article_description_param
    params.fetch(:description, "").to_s.strip
  end
end
