# frozen_string_literal: true

RecordingStudioEmbeddable.configure do |config|
  config.allowed_embedder_domains = []
  config.blocked_embedder_domains = []
  config.allow_any_domain = true
  config.require_publishable = true
  config.rate_limiter = :rails_cache
  # True only when the actor may edit this parent recording. False, or a
  # raised error, is a 404 on every management action.
  config.management_authorizer = lambda do |controller:, recording:|
    next false unless controller.respond_to?(:current_user, true)

    actor = controller.send(:current_user)
    next false if actor.blank? || recording.blank?
    next false unless defined?(RecordingStudioAccessible)

    RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :edit)
  end

  # Dummy keeps Artifacts off by default (Rails mount URLs). CDN tests flip
  # artifacts_enabled + embed_url_strategy. Screenshot / local runs may set
  # RECORDING_STUDIO_ARTIFACTS_ENABLED=true without changing the default.
  # See recording_studio_artifacts.rb.
  config.artifacts_enabled = ActiveModel::Type::Boolean.new.cast(
    ENV.fetch("RECORDING_STUDIO_ARTIFACTS_ENABLED", "false")
  )
  config.embed_url_strategy = :dedicated
  config.cdn_withhold_snippet_until_published = false
  config.cdn_publish_queue = :default
  config.floating_icon_hosts = ["images.example.com"]
  # sandbox and allow are optional. Unset, the popup iframe keeps the built-in sandbox.
  config.floating_defaults = {
    "edge_spacing" => 20,
    "popup_width" => 380,
    "popup_height" => 560,
    "icon_url" => nil,
    "label" => "Floating button"
  }
end
