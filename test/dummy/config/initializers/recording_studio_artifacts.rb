# frozen_string_literal: true

RecordingStudioArtifacts.configure do |config|
  # Prefer Rails credentials (development.yml.enc → dig :recording_studio_artifacts, :cdn).
  # Artifacts' own Credentials.fetch also reads that path, then ARTIFACT_CDN_* ENV
  # as a harmless optional override. Committed credentials.yml.enc keeps only
  # safe placeholders — never real R2 secrets in this public repo.
  cdn = ->(key) { DummyDevCredentials.dig(:recording_studio_artifacts, :cdn, key) }

  config.cdn_public_base_url =
    cdn.call(:public_base_url).presence || "https://artifacts.example.test"
  config.cdn_path_prefix =
    cdn.call(:path_prefix).presence || "recording_studio_artifacts"
  config.cdn_subdomain = cdn.call(:subdomain)
  config.cdn_domain = cdn.call(:domain)
  config.cdn_r2_account_id = cdn.call(:r2_account_id)
  config.cdn_r2_access_key_id = cdn.call(:r2_access_key_id)
  config.cdn_r2_secret_access_key = cdn.call(:r2_secret_access_key)
  config.cdn_r2_bucket = cdn.call(:r2_bucket)
  config.cdn_r2_endpoint = cdn.call(:r2_endpoint)
  config.cdn_r2_region = cdn.call(:r2_region).presence || "auto"
  config.cdn_cloudflare_zone_id = cdn.call(:cloudflare_zone_id)
  config.cdn_cloudflare_api_token = cdn.call(:cloudflare_api_token)
  config.cdn_publish_queue = :default

  # Test always uses MemoryStorage. Development uses real Artifacts CDN R2 only
  # when recording_studio_artifacts.cdn keys are present. Active Storage :r2
  # (Attachable uploads) is independent — without CDN keys, keep MemoryStorage.
  use_memory =
    Rails.env.test? ||
    !DummyDevCredentials.artifacts_cdn_configured?

  if use_memory
    storage = RecordingStudioArtifacts::Cdn::MemoryStorage.new
    config.cdn_storage = storage
    config.cdn_purger = storage
  end
end
