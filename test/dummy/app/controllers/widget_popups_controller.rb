# frozen_string_literal: true

# Public popup target for a floating launcher. Phase 3 replaces this with the
# interactive concern. It stays off the host session on purpose.
class WidgetPopupsController < ActionController::Base
  def show
    embed = RecordingStudioEmbeddable::Embed.find_by(token: params[:token].to_s)
    return head(:not_found) unless embed&.floating_enabled?

    head :ok
  end
end
