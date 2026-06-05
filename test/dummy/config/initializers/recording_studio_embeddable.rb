# frozen_string_literal: true

RecordingStudioEmbeddable.configure do |config|
  config.allowed_embedder_domains = []
  config.blocked_embedder_domains = []
  config.allow_any_domain = true
  config.embed_theme = {
    font_family: "Inter",
    background_color: "#ffffff",
    text_color: "#0f172a",
    muted_text_color: "#475569",
    accent_color: "#2563eb",
    border_color: "#e2e8f0",
    padding_scale: "md",
    radius_scale: "md",
    max_width: 1200,
    min_height: 320
  }
  config.require_publishable = true
  config.rate_limiter = :rails_cache
  config.management_authorizer = ->(controller:) { controller.respond_to?(:current_user, true) && controller.send(:current_user).present? }
end
