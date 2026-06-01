class PagesController < ApplicationController
  def show
    @page = @parent_recordable || Page.find(params[:id])
  end

  def embed
    @page = @parent_recordable || Page.find(params[:id])
    render :embed, layout: false
  end
end
