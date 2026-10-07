# frozen_string_literal: true

RecordingStudioEmbeddable.configure do |config|
  config.allowed_embedder_domains = []
  config.blocked_embedder_domains = []
  config.allow_any_domain = true
  config.require_publishable = true
  config.rate_limiter = :rails_cache
  config.management_authorizer = lambda do |controller:|
    next false unless controller.respond_to?(:current_user, true)

    user = controller.send(:current_user)
    user.present? && user.respond_to?(:RS_accessible, true) && user.RS_accessible
  end

  # CDN Strategy 1 — dummy exercises publish in tests/dev via MemoryStorage when
  # Spaces secrets are placeholders. Prefer ENV; credentials dig is documented in docs/CDN.md.
  # Hosts add recording_studio_embeddable.cdn.* to credentials (or EMBED_CDN_* env vars).
  config.cdn_public_base_url =
    ENV["EMBED_CDN_PUBLIC_BASE_URL"].presence ||
    Rails.application.credentials.dig(:recording_studio_embeddable, :cdn, :public_base_url).presence ||
    "https://embeds.example.test"
  config.cdn_object_prefix = "embeds"
  config.cdn_spaces_endpoint =
    ENV["EMBED_CDN_SPACES_ENDPOINT"].presence ||
    Rails.application.credentials.dig(:recording_studio_embeddable, :cdn, :spaces_endpoint)
  config.cdn_spaces_region =
    ENV["EMBED_CDN_SPACES_REGION"].presence ||
    Rails.application.credentials.dig(:recording_studio_embeddable, :cdn, :spaces_region)
  config.cdn_spaces_bucket =
    ENV["EMBED_CDN_SPACES_BUCKET"].presence ||
    Rails.application.credentials.dig(:recording_studio_embeddable, :cdn, :spaces_bucket)
  config.cdn_spaces_access_key_id =
    ENV["EMBED_CDN_SPACES_ACCESS_KEY_ID"].presence ||
    Rails.application.credentials.dig(:recording_studio_embeddable, :cdn, :spaces_access_key_id)
  config.cdn_spaces_secret_access_key =
    ENV["EMBED_CDN_SPACES_SECRET_ACCESS_KEY"].presence ||
    Rails.application.credentials.dig(:recording_studio_embeddable, :cdn, :spaces_secret_access_key)
  config.cdn_cloudflare_zone_id =
    ENV["EMBED_CDN_CLOUDFLARE_ZONE_ID"].presence ||
    Rails.application.credentials.dig(:recording_studio_embeddable, :cdn, :cloudflare_zone_id)
  config.cdn_cloudflare_api_token =
    ENV["EMBED_CDN_CLOUDFLARE_API_TOKEN"].presence ||
    Rails.application.credentials.dig(:recording_studio_embeddable, :cdn, :cloudflare_api_token)
  config.cdn_withhold_snippet_until_published = false

  # Dummy/test publish target: in-memory Spaces stand-in so CI can exercise overwrite-on-update
  # without real DigitalOcean credentials.
  if Rails.env.test? || Rails.env.development?
    config.cdn_storage = RecordingStudioEmbeddable::Cdn::MemoryStorage.new
    config.cdn_purger = config.cdn_storage
  end
end
