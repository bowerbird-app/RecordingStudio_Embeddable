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

  # Dummy keeps Artifacts off by default (Rails mount URLs). CDN tests flip
  # artifacts_enabled + embed_url_strategy. See recording_studio_artifacts.rb.
  config.artifacts_enabled = false
  config.embed_url_strategy = :dedicated
  config.cdn_withhold_snippet_until_published = false
  config.cdn_publish_queue = :default
end
