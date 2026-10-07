# frozen_string_literal: true

RecordingStudioArtifacts.configure do |config|
  # Dummy / test publish target: MemoryStorage so CDN publish works without R2 keys.
  # Production hosts set ARTIFACT_CDN_* (or credentials) and gem "aws-sdk-s3".
  # See RecordingStudio_artifacts docs/CDN.md and this gem's docs/CDN.md.
  config.cdn_public_base_url =
    ENV.fetch("ARTIFACT_CDN_PUBLIC_BASE_URL", nil).presence ||
    "https://artifacts.example.test"
  config.cdn_path_prefix =
    ENV.fetch("ARTIFACT_CDN_PATH_PREFIX", nil).presence ||
    "recording_studio_artifacts"
  config.cdn_publish_queue = :default

  if Rails.env.test? || Rails.env.development?
    storage = RecordingStudioArtifacts::Cdn::MemoryStorage.new
    config.cdn_storage = storage
    config.cdn_purger = storage
  end
end
