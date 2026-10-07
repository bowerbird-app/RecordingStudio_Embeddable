# frozen_string_literal: true

module RecordingStudioEmbeddable
  # CDN Strategy 1 helpers: stable partner URLs on DigitalOcean Spaces behind Cloudflare.
  #
  # Partner snippets always use the CDN hostname when +embed_url_strategy+ is +"cdn"+.
  # Object keys stay fixed (`embeds/{token}.html`) so content updates overwrite in place.
  module Cdn
    STRATEGY = "cdn"
    DEFAULT_OBJECT_PREFIX = "embeds"
    DEFAULT_CACHE_CONTROL = "public, max-age=300, stale-while-revalidate=60"

    module_function

    def strategy?(value)
      value.to_s == STRATEGY
    end

    def object_prefix
      prefix = RecordingStudioEmbeddable.configuration.cdn_object_prefix.presence || DEFAULT_OBJECT_PREFIX
      prefix.to_s.delete_prefix("/").delete_suffix("/")
    end

    def object_key(token)
      "#{object_prefix}/#{token}.html"
    end

    def object_path(token)
      "/#{object_key(token)}"
    end

    def public_base_url
      Credentials.public_base_url
    end

    def public_base_configured?
      public_base_url.present?
    end

    def public_url(token)
      base = public_base_url
      return unless base.present?

      "#{base.delete_suffix('/')}#{object_path(token)}"
    end

    def cache_control
      RecordingStudioEmbeddable.configuration.cdn_cache_control.presence || DEFAULT_CACHE_CONTROL
    end

    def withhold_snippet_until_published?
      RecordingStudioEmbeddable.configuration.cdn_withhold_snippet_until_published
    end

    # Resolves host-owned Spaces / Cloudflare settings from config, ENV, then credentials.
    module Credentials
      ENV_MAP = {
        public_base_url: "EMBED_CDN_PUBLIC_BASE_URL",
        spaces_endpoint: "EMBED_CDN_SPACES_ENDPOINT",
        spaces_region: "EMBED_CDN_SPACES_REGION",
        spaces_bucket: "EMBED_CDN_SPACES_BUCKET",
        spaces_access_key_id: "EMBED_CDN_SPACES_ACCESS_KEY_ID",
        spaces_secret_access_key: "EMBED_CDN_SPACES_SECRET_ACCESS_KEY",
        cloudflare_zone_id: "EMBED_CDN_CLOUDFLARE_ZONE_ID",
        cloudflare_api_token: "EMBED_CDN_CLOUDFLARE_API_TOKEN"
      }.freeze

      CONFIG_MAP = {
        public_base_url: :cdn_public_base_url,
        spaces_endpoint: :cdn_spaces_endpoint,
        spaces_region: :cdn_spaces_region,
        spaces_bucket: :cdn_spaces_bucket,
        spaces_access_key_id: :cdn_spaces_access_key_id,
        spaces_secret_access_key: :cdn_spaces_secret_access_key,
        cloudflare_zone_id: :cdn_cloudflare_zone_id,
        cloudflare_api_token: :cdn_cloudflare_api_token
      }.freeze

      CREDENTIAL_KEYS = CONFIG_MAP.keys.freeze

      module_function

      def fetch(key)
        key = key.to_sym
        from_config(key).presence || from_env(key).presence || from_credentials(key).presence
      end

      def public_base_url = fetch(:public_base_url)
      def spaces_endpoint = fetch(:spaces_endpoint)
      def spaces_region = fetch(:spaces_region)
      def spaces_bucket = fetch(:spaces_bucket)
      def spaces_access_key_id = fetch(:spaces_access_key_id)
      def spaces_secret_access_key = fetch(:spaces_secret_access_key)
      def cloudflare_zone_id = fetch(:cloudflare_zone_id)
      def cloudflare_api_token = fetch(:cloudflare_api_token)

      def spaces_configured?
        spaces_bucket.present? &&
          spaces_access_key_id.present? &&
          spaces_secret_access_key.present? &&
          spaces_endpoint.present? &&
          spaces_region.present?
      end

      def cloudflare_purge_configured?
        cloudflare_zone_id.present? && cloudflare_api_token.present?
      end

      def from_config(key)
        attr = CONFIG_MAP.fetch(key)
        RecordingStudioEmbeddable.configuration.public_send(attr)
      rescue NoMethodError
        nil
      end

      def from_env(key)
        ENV.fetch(ENV_MAP.fetch(key), nil).to_s.strip.presence
      end

      def from_credentials(key)
        return unless defined?(Rails) && Rails.application.respond_to?(:credentials)

        Rails.application.credentials.dig(:recording_studio_embeddable, :cdn, key)
      rescue ActiveSupport::EncryptedFile::MissingKeyError, ArgumentError
        nil
      end
    end
  end
end
