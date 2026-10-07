# frozen_string_literal: true

RecordingStudioEmbeddable.configure do |config|
  config.public_embeds_enabled = true
  # :dedicated serves App Platform Rails. :cdn publishes static HTML to DigitalOcean Spaces
  # behind Cloudflare — partner snippets then use the CDN URL only (never the Rails mount).
  config.embed_url_strategy = :dedicated
  config.allowed_embed_modes = %i[iframe oembed]
  config.default_embed_mode = :iframe
  config.allowed_embedder_domains = []
  config.blocked_embedder_domains = []
  config.require_domain_allowlist = true
  config.allow_any_domain = false
  config.require_publishable = true
  config.fallback_to_publishable_renderer = false
  config.rate_limiting_enabled = true
  config.rate_limiter = :rails_cache
  config.rate_limit = 120
  config.rate_limit_window = 60
  config.rate_limit_fail_closed = false
  config.cache_mode = :http_validation
  config.cache_policy = { public: true, max_age: 300, stale_while_revalidate: 60 }
  # Embed styling inherits your host app's FlatPack theme by default.
  # Declare per-recordable customizable styles with
  # `customizable_embed_styles:` on RecordingStudio::Capabilities::Embeddable.
  config.view_logging_enabled = true
  config.async_view_logging = true
  config.view_log_raw_ip = false
  config.view_log_raw_user_agent = false
  config.view_log_raw_referer = false

  # CDN Strategy 1 (DigitalOcean Spaces + Cloudflare). Host owns infra.
  # Prefer ENV in production; credentials dig is supported for local/dummy.
  # See docs/CDN.md for the full variable list and frame-ancestors Worker notes.
  config.cdn_public_base_url = ENV["EMBED_CDN_PUBLIC_BASE_URL"]
  config.cdn_object_prefix = "embeds"
  config.cdn_spaces_endpoint = ENV["EMBED_CDN_SPACES_ENDPOINT"]
  config.cdn_spaces_region = ENV["EMBED_CDN_SPACES_REGION"]
  config.cdn_spaces_bucket = ENV["EMBED_CDN_SPACES_BUCKET"]
  config.cdn_spaces_access_key_id = ENV["EMBED_CDN_SPACES_ACCESS_KEY_ID"]
  config.cdn_spaces_secret_access_key = ENV["EMBED_CDN_SPACES_SECRET_ACCESS_KEY"]
  config.cdn_cloudflare_zone_id = ENV["EMBED_CDN_CLOUDFLARE_ZONE_ID"]
  config.cdn_cloudflare_api_token = ENV["EMBED_CDN_CLOUDFLARE_API_TOKEN"]
  config.cdn_withhold_snippet_until_published = false
  config.cdn_publish_queue = :default

  config.management_authorizer = lambda do |controller:|
    next false unless controller.respond_to?(:current_user, true)

    user = controller.send(:current_user)
    user.present? && user.respond_to?(:RS_accessible, true) && user.RS_accessible
  end
end
