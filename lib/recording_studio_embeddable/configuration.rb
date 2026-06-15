# frozen_string_literal: true

module RecordingStudioEmbeddable
  class Configuration
    attr_accessor(
      :allowed_embedder_domains,
      :blocked_embedder_domains,
      :public_embeds_enabled,
      :renderer_resolver,
      :embed_renderer_resolver,
      :require_publishable,
      :embed_url_strategy,
      :allowed_embed_modes,
      :default_embed_mode,
      :fallback_to_publishable_renderer,
      :require_domain_allowlist,
      :allow_any_domain,
      :default_sizing,
      :rate_limiter,
      :redis,
      :rate_limit,
      :rate_limit_window,
      :rate_limit_fail_closed,
      :rate_limiting_enabled,
      :cache_policy,
      :cache_mode,
      :public_embed_cache_control,
      :allow_custom_styling,
      :view_logging_enabled,
      :async_view_logging,
      :view_logging_mode,
      :view_logging_queue,
      :view_log_success_sample_rate,
      :view_log_blocked_sample_rate,
      :view_log_error_sample_rate,
      :view_log_raw_ip,
      :view_log_raw_user_agent,
      :view_log_raw_referer,
      :view_log_salt,
      :view_summary_enabled,
      :bot_detector,
      :management_authorizer,
      :token_bytes,
      :prune_views_after
    )
    attr_reader :hooks

    def initialize
      @allowed_embedder_domains = []
      @blocked_embedder_domains = []
      @public_embeds_enabled = true
      @renderer_resolver = nil
      @embed_renderer_resolver = nil
      @require_publishable = true
      @embed_url_strategy = :dedicated
      @allowed_embed_modes = %i[iframe oembed]
      @default_embed_mode = :iframe
      @fallback_to_publishable_renderer = false
      @require_domain_allowlist = true
      @allow_any_domain = false
      @default_sizing = { "mode" => "responsive", "aspect_ratio" => "16:9", "max_width" => 1200, "min_height" => 320 }
      @rate_limiter = :null
      @redis = nil
      @rate_limit = 120
      @rate_limit_window = 60
      @rate_limit_fail_closed = false
      @rate_limiting_enabled = true
      @cache_policy = { public: true, max_age: 300, stale_while_revalidate: 60 }
      @cache_mode = :http_validation
      @public_embed_cache_control = "public, max-age=300, stale-while-revalidate=60"
      @allow_custom_styling = true
      @view_logging_enabled = true
      @async_view_logging = true
      @view_logging_mode = :async
      @view_logging_queue = :low_priority
      @view_log_success_sample_rate = 1.0
      @view_log_blocked_sample_rate = 1.0
      @view_log_error_sample_rate = 1.0
      @view_log_raw_ip = false
      @view_log_raw_user_agent = false
      @view_log_raw_referer = false
      @view_log_salt = nil
      @view_summary_enabled = true
      @bot_detector = nil
      @management_authorizer = lambda { |controller:|
        next false unless controller.respond_to?(:current_user, true)

        user = controller.send(:current_user)
        user.present? && user.respond_to?(:RS_accessible, true) && user.public_send(:RS_accessible)
      }
      @token_bytes = 24
      @prune_views_after = 90.respond_to?(:days) ? 90.days : 90 * 24 * 60 * 60
      @hooks = Hooks.new
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end
    end

    def to_h
      {
        allowed_embedder_domains: allowed_embedder_domains,
        blocked_embedder_domains: blocked_embedder_domains,
        public_embeds_enabled: public_embeds_enabled,
        require_publishable: require_publishable,
        embed_url_strategy: embed_url_strategy,
        allowed_embed_modes: allowed_embed_modes,
        default_embed_mode: default_embed_mode,
        require_domain_allowlist: require_domain_allowlist,
        allow_any_domain: allow_any_domain,
        rate_limiter: rate_limiter,
        redis: redis,
        rate_limit: rate_limit,
        rate_limit_window: rate_limit_window,
        rate_limit_fail_closed: rate_limit_fail_closed,
        rate_limiting_enabled: rate_limiting_enabled,
        cache_mode: cache_mode,
        cache_policy: cache_policy,
        allow_custom_styling: allow_custom_styling,
        view_logging_enabled: view_logging_enabled,
        async_view_logging: async_view_logging,
        token_bytes: token_bytes,
        prune_views_after: prune_views_after,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end
  end
end
