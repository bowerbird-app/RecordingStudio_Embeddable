# frozen_string_literal: true

# Public demo pages for the floating launcher. These stay off the host session.
class WidgetSitesController < ActionController::Base
  def local
    tokens = params[:tokens].to_s.split(",").map(&:strip).compact_blank
    @recordings = tokens.filter_map { |token| RecordingStudioEmbeddable::Embed.find_by(token: token)&.parent_recording }
    render layout: "widget_site"
  end

  def installed
    embed = RecordingStudioEmbeddable::Embed.find_by(token: params[:token].to_s)
    @recording = embed&.parent_recording
    return head(:not_found) unless @recording

    render layout: "widget_installed"
  end
end
