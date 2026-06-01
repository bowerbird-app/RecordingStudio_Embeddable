# frozen_string_literal: true

module RecordingStudioEmbeddable
  class CachePolicy
    def self.resolve(embed:, recording:)
      recordable_options = Renderer.options_for(recording)
      configured = RecordingStudioEmbeddable.configuration.cache_policy
      configured = configured.call(embed, recording) if configured.respond_to?(:call)
      configured = {} unless configured.respond_to?(:to_h)
      model_cache = cache_options_from(recordable_options)

      # Model-level caching is opt-in. A recordable must explicitly set `cache:` or
      # `cache_policy:` in its embeddable options to enable HTTP caching.
      defaults = { enabled: false, public: true, max_age: 300, stale_while_revalidate: 60 }
      defaults.merge(configured.to_h.symbolize_keys).merge(model_cache)
    end

    def self.cache_options_from(recordable_options)
      options = {}

      cache = recordable_options[:cache]
      case cache
      when true, false
        options[:enabled] = cache
      when Hash
        options[:enabled] = true
        options.merge!(cache.symbolize_keys)
      end

      cache_policy = recordable_options[:cache_policy]
      if !cache_policy.nil? && cache_policy.respond_to?(:to_h)
        options[:enabled] = true if options[:enabled].nil?
        options.merge!(cache_policy.to_h.symbolize_keys)
      end
      options
    end
  end
end
