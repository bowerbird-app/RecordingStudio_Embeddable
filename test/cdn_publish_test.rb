# frozen_string_literal: true

require "test_helper"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/hash/deep_merge"
require "active_support/core_ext/string/inflections"

class CdnPublishTest < Minitest::Test
  FakeRecordable = Struct.new(:title) do
    def self.recording_studio_embeddable_options
      { enabled: true, renderer: "recording_studio_embeddable/embeds/default", require_publishable: false }
    end

    def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")
  end

  FakeRecording = Struct.new(:recordable, :updated_at, :id) do
    def currently_published? = true
  end

  class FakeEmbed
    attr_accessor :token, :enabled, :embed_url_strategy, :metadata, :id,
                  :allowed_embedder_domains, :blocked_embedder_domains,
                  :inherit_global_domains, :inherit_capability_domains,
                  :appearance, :sizing, :updated_at, :parent_recording

    def initialize(token:)
      @token = token
      @enabled = true
      @embed_url_strategy = "cdn"
      @metadata = {}
      @id = "embed-#{token}"
      @allowed_embedder_domains = ["partner.example"]
      @blocked_embedder_domains = []
      @inherit_global_domains = true
      @inherit_capability_domains = true
      @appearance = {}
      @sizing = {}
      @updated_at = Time.now.utc
      @published_calls = []
    end

    def enabled? = !!@enabled
    def cdn_url_strategy? = RecordingStudioEmbeddable::Cdn.strategy?(embed_url_strategy)
    def cdn_object_key = RecordingStudioEmbeddable::Cdn.object_key(token)
    def allowed_domains = Array(@allowed_embedder_domains)
    def blocked_domains = Array(@blocked_embedder_domains)

    def mark_cdn_published!(key:, public_url:, etag: nil)
      @metadata = (@metadata || {}).deep_dup
      @metadata["cdn"] = {
        "published_at" => Time.now.utc.iso8601,
        "object_key" => key,
        "public_url" => public_url,
        "etag" => etag
      }.compact
      @published_calls << @metadata["cdn"]
    end

    def cdn_published?
      metadata.dig("cdn", "published_at").present?
    end

    def public_path
      return RecordingStudioEmbeddable::Cdn.object_path(token) if cdn_url_strategy?

      "/recording_studio_embeddable/embeds/#{token}"
    end

    def public_url(host: nil, protocol: nil)
      if cdn_url_strategy?
        return unless RecordingStudioEmbeddable::Cdn.public_base_configured?

        return RecordingStudioEmbeddable::Cdn.public_url(token)
      end

      path = "/recording_studio_embeddable/embeds/#{token}"
      return path if host.blank?

      "#{protocol || 'https'}://#{host}#{path}"
    end
  end

  def setup
    RecordingStudioEmbeddable.reset_configuration!
    @storage = RecordingStudioEmbeddable::Cdn::MemoryStorage.new
    RecordingStudioEmbeddable.configure do |config|
      config.embed_url_strategy = :cdn
      config.cdn_public_base_url = "https://embeds.example.test"
      config.cdn_object_prefix = "embeds"
      config.cdn_storage = @storage
      config.cdn_purger = @storage
      config.allow_any_domain = false
      config.require_domain_allowlist = true
      config.require_publishable = false
      config.public_embeds_enabled = true
    end
  end

  def teardown
    RecordingStudioEmbeddable.reset_configuration!
  end

  def test_cdn_public_url_is_stable_and_never_rails_mount
    embed = FakeEmbed.new(token: "stabletoken123")
    url = embed.public_url(host: "app.example.com", protocol: "https")

    assert_equal "https://embeds.example.test/embeds/stabletoken123.html", url
    refute_includes url, "recording_studio_embeddable"
    assert_equal "/embeds/stabletoken123.html", embed.public_path
    assert_equal "embeds/stabletoken123.html", embed.cdn_object_key
  end

  def test_dedicated_strategy_keeps_rails_mount_path
    RecordingStudioEmbeddable.configuration.embed_url_strategy = :dedicated
    embed = FakeEmbed.new(token: "dedicatedtoken")
    embed.embed_url_strategy = "dedicated"

    assert_equal "/recording_studio_embeddable/embeds/dedicatedtoken", embed.public_path
    assert_equal "https://app.example.com/recording_studio_embeddable/embeds/dedicatedtoken",
                 embed.public_url(host: "app.example.com", protocol: "https")
  end

  def test_publish_overwrites_same_object_key_and_purges
    embed = build_embed(token: "overwrite-token")
    stub_document_render("<html><head></head><body>v1</body></html>") do
      first = publish_embed(embed)
      assert first.success?, first.error

      key = "embeds/overwrite-token.html"
      assert_equal key, first.value[:key]
      assert_equal "https://embeds.example.test/embeds/overwrite-token.html", first.value[:public_url]
      first_body = @storage.read(key)[:body]
      assert_includes first_body, "v1"
      assert_includes @storage.purges, first.value[:public_url]

      embed.allowed_embedder_domains = ["partner.example", "other.example"]
      stub_document_render("<html><head></head><body>v2 other.example</body></html>") do
        second = publish_embed(embed)
        assert second.success?, second.error

        assert_equal key, second.value[:key]
        assert_equal first.value[:public_url], second.value[:public_url]
        assert_equal 1, @storage.objects.size
        second_body = @storage.read(key)[:body]
        refute_equal first_body, second_body
        assert_includes second_body, "other.example"
        assert_equal 2, @storage.purges.size
        assert embed.cdn_published?
      end
    end
  end

  def test_publish_bakes_frame_ancestors_from_domain_policy
    embed = build_embed(token: "csp-token")
    stub_document_render("<html><head></head><body>csp</body></html>") do
      result = publish_embed(embed)
      assert result.success?, result.error

      object = @storage.read(embed.cdn_object_key)
      assert_includes object[:metadata]["content-security-policy"], "frame-ancestors"
      assert_includes object[:metadata]["content-security-policy"], "https://partner.example"
      assert_includes object[:body], "csp"
      assert_includes result.value[:frame_ancestors].join(" "), "partner.example"
    end
  end

  def test_unavailable_embed_overwrites_with_none_ancestors
    embed = build_embed(token: "off-token")
    embed.enabled = false
    result = publish_embed(embed)
    assert result.success?, result.error
    assert_equal false, result.value[:available]
    assert_includes @storage.read(embed.cdn_object_key)[:body], "Embed unavailable"
    assert_includes @storage.read(embed.cdn_object_key)[:metadata]["content-security-policy"], "'none'"
  end

  def test_credentials_env_map_documents_host_vars
    expected = %w[
      EMBED_CDN_PUBLIC_BASE_URL
      EMBED_CDN_SPACES_ENDPOINT
      EMBED_CDN_SPACES_REGION
      EMBED_CDN_SPACES_BUCKET
      EMBED_CDN_SPACES_ACCESS_KEY_ID
      EMBED_CDN_SPACES_SECRET_ACCESS_KEY
      EMBED_CDN_CLOUDFLARE_ZONE_ID
      EMBED_CDN_CLOUDFLARE_API_TOKEN
    ]
    assert_equal expected.sort, RecordingStudioEmbeddable::Cdn::Credentials::ENV_MAP.values.sort
  end

  def test_credentials_prefer_config_then_env
    RecordingStudioEmbeddable.configuration.cdn_public_base_url = "https://from-config.test"
    ENV["EMBED_CDN_PUBLIC_BASE_URL"] = "https://from-env.test"
    assert_equal "https://from-config.test", RecordingStudioEmbeddable::Cdn::Credentials.public_base_url

    RecordingStudioEmbeddable.configuration.cdn_public_base_url = nil
    assert_equal "https://from-env.test", RecordingStudioEmbeddable::Cdn::Credentials.public_base_url
  ensure
    ENV.delete("EMBED_CDN_PUBLIC_BASE_URL")
  end

  def test_publish_rejects_dedicated_strategy
    embed = build_embed(token: "dedicated-reject")
    embed.embed_url_strategy = "dedicated"
    result = publish_embed(embed)
    assert result.failure?
    assert_match(/CDN URL strategy/, result.error)
  end

  def test_cloudflare_purge_noops_without_urls
    purger = RecordingStudioEmbeddable::Cdn::CloudflarePurge.new(zone_id: "zone", api_token: "token")
    assert_equal({ purged: [] }, purger.purge_urls([]))
  end

  def test_inject_unavailable_html_includes_csp_none
    embed = build_embed(token: "inject-token")
    embed.enabled = false
    result = publish_embed(embed)
    assert result.success?, result.error
    body = @storage.read(embed.cdn_object_key)[:body]
    assert_includes body, "recording-studio-embeddable-csp:"
    assert_includes body, "frame-ancestors 'none'"
  end

  def test_withhold_snippet_until_published
    RecordingStudioEmbeddable.configuration.cdn_withhold_snippet_until_published = true
    recording = Object.new
    embed = FakeEmbed.new(token: "withhold-token")
    recording.define_singleton_method(:embed) { embed }
    recording.extend(RecordingStudioEmbeddable::RecordingMethods)

    assert_equal "", recording.embed_code
    embed.mark_cdn_published!(key: embed.cdn_object_key, public_url: embed.public_url)
    html = recording.embed_code
    assert_includes html, "https://embeds.example.test/embeds/withhold-token.html"
    refute_includes html, "recording_studio_embeddable"
  end

  private

  def publish_embed(embed)
    RecordingStudioEmbeddable::Services::PublishEmbedToCdn.call(
      embed: embed, storage: @storage, purger: @storage
    )
  end

  def build_embed(token:)
    embed = FakeEmbed.new(token: token)
    recording = FakeRecording.new(FakeRecordable.new("Hello"), Time.now.utc, "rec-1")
    embed.parent_recording = recording
    embed
  end

  def stub_document_render(html)
    klass = RecordingStudioEmbeddable::Services::RenderEmbedDocument
    result = RecordingStudioEmbeddable::Services::BaseService::Result.new(success: true, value: html)
    original = klass.method(:call)
    klass.define_singleton_method(:call) { |**_| result }
    yield
  ensure
    klass.define_singleton_method(:call, original)
  end
end
