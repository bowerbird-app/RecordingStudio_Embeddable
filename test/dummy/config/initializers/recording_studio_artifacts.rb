# frozen_string_literal: true

RecordingStudioArtifacts.configure do |config|
  # Dummy / test: MemoryStorage + fake public_base_url so publish works without R2.
  # Hosts own real secrets via ARTIFACT_CDN_* ENV or credentials under
  # recording_studio_artifacts.cdn (see docs/CDN.md). Do not ship production R2
  # keys in this gem. Dummy credentials.yml.enc only shows the key shape with
  # safe placeholders under the shared RecordingStudio_* master key.
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
