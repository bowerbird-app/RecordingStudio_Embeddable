class PagesController < ApplicationController
  def embed
    @page = Page.find(params[:id])
    render :embed, layout: false
  end
end
