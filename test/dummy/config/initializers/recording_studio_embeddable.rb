# frozen_string_literal: true

RecordingStudioEmbeddable.configure do |config|
  config.allowed_embedder_domains = []
  config.blocked_embedder_domains = []
  config.allow_any_domain = true
  config.embed_theme = {
    font_family: "ui-sans-serif, system-ui, -apple-system, Segoe UI, sans-serif",
    background_color: "transparent",
    text_color: "#0f172a",
    muted_text_color: "#475569",
    accent_color: "#2563eb",
    border_color: "#e2e8f0",
    custom_properties: {
      # "--rse-embed-radius" => "0.75rem"
    }
  }
  config.require_publishable = true
  config.rate_limiter = :rails_cache
  config.management_authorizer = ->(controller:) { controller.respond_to?(:current_user, true) && controller.send(:current_user).present? }
end
