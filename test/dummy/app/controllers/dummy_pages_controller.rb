# frozen_string_literal: true

class DummyPagesController < ApplicationController
  def new
    @next_page_title = next_page_title
  end

  def create
    page = Page.create!(title: page_title_param.presence || next_page_title)
    recording = RecordingStudio::Recording.create!(recordable: page, parent_recording: workspace_root_recording)
    recording.ensure_embed!(enabled: true, allowed_embedder_domains: ["example.com"]) if recording.respond_to?(:ensure_embed!)

    redirect_to root_path, notice: "Added #{page.title}"
  end

  private

  def workspace_root_recording
    existing_root = RecordingStudio::Recording.where(recordable_type: "Workspace", parent_recording_id: nil)
      .includes(:recordable)
      .order(:created_at, :id)
      .first
    return existing_root if existing_root

    workspace = Workspace.create!(name: "Dummy Workspace")
    RecordingStudio::Recording.create!(recordable: workspace)
  end

  def next_page_title
    "Dummy Page #{Page.count + 1}"
  end

  def page_title_param
    params.fetch(:title, "").to_s.strip
  end
end
