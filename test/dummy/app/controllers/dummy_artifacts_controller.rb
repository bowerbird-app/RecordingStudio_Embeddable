# frozen_string_literal: true

# Dummy-only stand-in for the Artifacts CDN edge: serves HTML published into
# MemoryStorage (same process) or a tmp file written by local screenshot/publish
# helpers, at /recording_studio_artifacts/:artifact_id.
class DummyArtifactsController < ActionController::Base
  def show
    artifact_id = params[:artifact_id].to_s
    body = memory_body(artifact_id) || disk_body(artifact_id)
    return head :not_found if body.blank?

    response.set_header("X-Dummy-Artifacts-Source", "memory-or-disk")
    render html: body.to_s.html_safe, layout: false
  end

  private

  def memory_body(artifact_id)
    storage = RecordingStudioArtifacts.configuration.cdn_storage
    return unless storage.respond_to?(:read)

    prefix = RecordingStudioArtifacts.configuration.cdn_path_prefix.presence ||
             "recording_studio_artifacts"
    stored = storage.read("#{prefix}/#{artifact_id}")
    return if stored.blank?

    stored.is_a?(Hash) ? stored[:body] || stored["body"] : stored
  rescue StandardError
    nil
  end

  def disk_body(artifact_id)
    path = Rails.root.join("tmp/dummy_artifacts/#{artifact_id}.html")
    return unless path.file?

    path.read
  end
end
