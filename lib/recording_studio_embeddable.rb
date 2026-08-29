# frozen_string_literal: true

require "recording_studio_embeddable/version"
require "openssl"
require "uri"
require "recording_studio_embeddable/hooks"
require "recording_studio_embeddable/configuration"
require "recording_studio_embeddable/recordable"
require "recording_studio_embeddable/capabilities/embeddable"
require "recording_studio_embeddable/styling/tokens"
require "recording_studio_embeddable/styling/width_mode"
require "recording_studio_embeddable/styling/definitions"
require "recording_studio_embeddable/styling/recordable_defaults"
require "recording_studio_embeddable/styling/resolve_theme"
require "recording_studio_embeddable/styling/validate_overrides"
require "recording_studio_embeddable/renderer"
require "recording_studio_embeddable/recording_methods"
require "recording_studio_embeddable/cache_policy"
require "recording_studio_embeddable/security/domain_policy"
require "recording_studio_embeddable/security/public_access"
require "recording_studio_embeddable/services/base_service"
require "recording_studio_embeddable/services/bot_detector"
require "recording_studio_embeddable/services/normalize_payload"
require "recording_studio_embeddable/services/log_view"
require "recording_studio_embeddable/services/capture_view"
require "recording_studio_embeddable/services/google_fonts"
require "recording_studio_embeddable/rate_limiters/null"
require "recording_studio_embeddable/rate_limiters/rails_cache"
require "recording_studio_embeddable/rate_limiters/redis"
require "recording_studio_embeddable/engine"

module RecordingStudioEmbeddable
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
