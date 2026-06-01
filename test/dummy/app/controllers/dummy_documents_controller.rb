# frozen_string_literal: true

class DummyDocumentsController < ApplicationController
  def edit
    @document = Document.find(params[:id])
  end

  def update
    document = Document.find(params[:id])
    document.update!(
      title: document_title_param.presence || document.title,
      description: document_description_param
    )

    redirect_to root_path, notice: "Updated #{document.title}"
  end

  private

  def document_title_param
    params.fetch(:title, "").to_s.strip
  end

  def document_description_param
    params.fetch(:description, "").to_s.strip
  end
end
