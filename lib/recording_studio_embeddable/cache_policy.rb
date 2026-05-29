# frozen_string_literal: true

module RecordingStudioEmbeddable
  class CachePolicy
    def self.resolve(embed:, recording:)
      configured = RecordingStudioEmbeddable.configuration.cache_policy
      configured = configured.call(embed, recording) if configured.respond_to?(:call)
      configured = {} unless configured.respond_to?(:to_h)

      { public: true, max_age: 300, stale_while_revalidate: 60 }.merge(configured.to_h.symbolize_keys)
    end
  end
end
