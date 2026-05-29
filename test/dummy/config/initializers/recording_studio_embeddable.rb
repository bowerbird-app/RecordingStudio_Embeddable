# frozen_string_literal: true

RecordingStudioEmbeddable.configure do |config|
  config.allowed_embedder_domains = []
  config.blocked_embedder_domains = []
  config.require_publishable = true
  config.rate_limiter = :rails_cache
  config.management_authorizer = ->(controller:) { controller.respond_to?(:current_user, true) && controller.send(:current_user).present? }
end
