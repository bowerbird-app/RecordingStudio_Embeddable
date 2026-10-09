# frozen_string_literal: true

RecordingStudioArtifacts.configure do |config|
  # Prefer ARTIFACT_CDN_* ENV (optionally loaded from gitignored local_r2.yml /
  # .env.development.local in development). Committed credentials.yml.enc keeps
  # only safe placeholders — never real R2 secrets in this public repo.
  config.cdn_public_base_url =
    ENV.fetch("ARTIFACT_CDN_PUBLIC_BASE_URL", nil).presence ||
    "https://artifacts.example.test"
  config.cdn_path_prefix =
    ENV.fetch("ARTIFACT_CDN_PATH_PREFIX", nil).presence ||
    "recording_studio_artifacts"
  config.cdn_subdomain = ENV.fetch("ARTIFACT_CDN_SUBDOMAIN", nil).presence
  config.cdn_domain = ENV.fetch("ARTIFACT_CDN_DOMAIN", nil).presence
  config.cdn_r2_account_id = ENV.fetch("ARTIFACT_CDN_R2_ACCOUNT_ID", nil).presence
  config.cdn_r2_access_key_id = ENV.fetch("ARTIFACT_CDN_R2_ACCESS_KEY_ID", nil).presence
  config.cdn_r2_secret_access_key = ENV.fetch("ARTIFACT_CDN_R2_SECRET_ACCESS_KEY", nil).presence
  config.cdn_r2_bucket = ENV.fetch("ARTIFACT_CDN_R2_BUCKET", nil).presence
  config.cdn_r2_endpoint = ENV.fetch("ARTIFACT_CDN_R2_ENDPOINT", nil).presence
  config.cdn_r2_region = ENV.fetch("ARTIFACT_CDN_R2_REGION", nil).presence || "auto"
  config.cdn_cloudflare_zone_id = ENV.fetch("ARTIFACT_CDN_CLOUDFLARE_ZONE_ID", nil).presence
  config.cdn_cloudflare_api_token = ENV.fetch("ARTIFACT_CDN_CLOUDFLARE_API_TOKEN", nil).presence
  config.cdn_publish_queue = :default

  # Test always uses MemoryStorage. Development uses real R2 only when ENV /
  # gitignored local_r2.yml supplies keys (DummyLocalR2). Committed credential
  # placeholders must not count as configured R2.
  use_memory =
    Rails.env.test? ||
    (Rails.env.development? && !DummyLocalR2.r2_active_storage_configured?)

  if use_memory
    storage = RecordingStudioArtifacts::Cdn::MemoryStorage.new
    config.cdn_storage = storage
    config.cdn_purger = storage
  end
end
