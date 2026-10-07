# frozen_string_literal: true

module RecordingStudioEmbeddable
  # CDN URL strategy helpers. Publish itself goes through RecordingStudioArtifacts
  # (Cloudflare R2). Embeddable stores the returned artifact id + public_url and
  # never uploads to DigitalOcean Spaces.
  module Cdn
    STRATEGY = "cdn"

    module_function

    def strategy?(value)
      value.to_s == STRATEGY
    end

    def withhold_snippet_until_published?
      !!RecordingStudioEmbeddable.configuration.cdn_withhold_snippet_until_published
    end

    def artifacts_available?
      defined?(RecordingStudioArtifacts) &&
        RecordingStudioArtifacts.respond_to?(:publish) &&
        RecordingStudioArtifacts.respond_to?(:update)
    end
  end
end
