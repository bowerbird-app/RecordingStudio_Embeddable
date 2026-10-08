# frozen_string_literal: true

RecordingStudioEmbeddable.configure do |config|
  config.public_embeds_enabled = true
  # Host-wide Artifacts/CDN usage switch (default off). The Artifacts gem is
  # always installed with Embeddable; this only controls whether Embeddable
  # enqueues publish/purge jobs and returns CDN URLs. When false, partner URLs
  # stay on the Rails mount. See docs/CDN.md.
  config.artifacts_enabled = false
  # :dedicated serves App Platform Rails. :cdn publishes iframe HTML via
  # RecordingStudioArtifacts (Cloudflare R2) — partner snippets then use the
  # Artifacts public URL only (never the Rails mount). Only used when
  # artifacts_enabled is true.
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

  # CDN via RecordingStudioArtifacts (only when artifacts_enabled). Host owns
  # ARTIFACT_CDN_* / R2 / DNS. Install Artifacts before enabling.
  config.cdn_withhold_snippet_until_published = false
  config.cdn_publish_queue = :default

  config.management_authorizer = lambda do |controller:|
    next false unless controller.respond_to?(:current_user, true)

    user = controller.send(:current_user)
    user.present? && user.respond_to?(:RS_accessible, true) && user.RS_accessible
  end
end
