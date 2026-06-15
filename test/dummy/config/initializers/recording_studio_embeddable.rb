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
    user.present? && user.respond_to?(:RS_accessible, true) && user.public_send(:RS_accessible)
  end
end
