# frozen_string_literal: true

# Dummy-only stand-in for an R2/custom-domain image host.
# Serves Active Storage blobs by key so Attachable direct URLs resolve locally
# for screenshots and manual checks. Not for production hosts.
class DummyCdnController < ActionController::Base
  def show
    key = params[:key].to_s.delete_prefix("/")
    return head :not_found if key.blank?

    blob = ActiveStorage::Blob.find_by(key: key)
    return head :not_found if blob.blank?
    return head :not_found unless blob.service.exist?(blob.key)

    response.set_header("Cache-Control", "public, max-age=86400")
    response.set_header("Content-Type", blob.content_type) if blob.content_type.present?
    send_data blob.download,
              type: blob.content_type.presence || "application/octet-stream",
              disposition: "inline",
              filename: blob.filename.to_s
  end
end
