# frozen_string_literal: true

require "test_helper"

class ArtifactsEnabledTest < Minitest::Test
  class FakeEmbed
    attr_accessor :token, :enabled, :embed_url_strategy, :metadata, :id

    def initialize(token:)
      @token = token
      @enabled = true
      @embed_url_strategy = "cdn"
      @metadata = {}
      @id = "embed-#{token}"
    end

    def cdn_url_strategy?
      RecordingStudioEmbeddable::Cdn.enabled? &&
        RecordingStudioEmbeddable::Cdn.strategy?(embed_url_strategy)
    end

    def public_path
      return artifact_public_path if cdn_url_strategy?

      "/recording_studio_embeddable/embeds/#{token}"
    end

    def public_url(host: nil, protocol: nil)
      return artifact_public_url if cdn_url_strategy?

      path = "/recording_studio_embeddable/embeds/#{token}"
      return path if host.blank?

      "#{protocol || 'https'}://#{host}#{path}"
    end

    def artifact_id
      metadata.dig("artifact", "id")
    end

    def artifact_public_url
      metadata.dig("artifact", "public_url")
    end

    def artifact_public_path
      url = artifact_public_url
      return URI.parse(url).path if url.present?

      nil
    rescue URI::InvalidURIError
      nil
    end

    def cdn_published?
      metadata.dig("artifact", "published_at").present?
    end

    def enqueue_cdn_publish!
      return unless cdn_url_strategy?

      :would_enqueue
    end
  end

  def setup
    RecordingStudioEmbeddable.reset_configuration!
    RecordingStudioEmbeddable.configuration.embed_url_strategy = :cdn
  end

  def teardown
    RecordingStudioEmbeddable.reset_configuration!
  end

  def test_default_artifacts_enabled_is_false
    RecordingStudioEmbeddable.reset_configuration!

    refute RecordingStudioEmbeddable.configuration.artifacts_enabled
    refute RecordingStudioEmbeddable::Cdn.enabled?
  end

  def test_artifacts_off_uses_host_rails_urls_even_when_strategy_is_cdn
    RecordingStudioEmbeddable.configuration.artifacts_enabled = false
    embed = build_cdn_embed

    refute embed.cdn_url_strategy?
    assert_equal "/recording_studio_embeddable/embeds/#{embed.token}", embed.public_path
    assert_equal(
      "https://app.example.com/recording_studio_embeddable/embeds/#{embed.token}",
      embed.public_url(host: "app.example.com", protocol: "https")
    )
  end

  def test_artifacts_on_uses_cdn_urls_when_strategy_is_cdn
    RecordingStudioEmbeddable.configuration.artifacts_enabled = true
    embed = build_cdn_embed

    assert embed.cdn_url_strategy?
    assert_equal(
      "https://artifacts.example.test/recording_studio_artifacts/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      embed.public_url(host: "app.example.com", protocol: "https")
    )
    refute_includes embed.public_path, "recording_studio_embeddable"
  end

  def test_artifacts_off_skips_enqueue_path
    RecordingStudioEmbeddable.configuration.artifacts_enabled = false
    embed = build_cdn_embed

    refute embed.cdn_url_strategy?
    assert_nil embed.enqueue_cdn_publish!
  end

  def test_artifacts_on_would_enqueue
    RecordingStudioEmbeddable.configuration.artifacts_enabled = true
    embed = build_cdn_embed

    assert_equal :would_enqueue, embed.enqueue_cdn_publish!
  end

  def test_switching_on_to_off_falls_back_without_clearing_artifact_metadata
    RecordingStudioEmbeddable.configuration.artifacts_enabled = true
    embed = build_cdn_embed
    assert embed.cdn_url_strategy?
    assert embed.cdn_published?

    RecordingStudioEmbeddable.configuration.artifacts_enabled = false

    refute embed.cdn_url_strategy?
    assert_equal "/recording_studio_embeddable/embeds/#{embed.token}", embed.public_path
    assert_equal "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", embed.artifact_id
    assert embed.cdn_published?
  end

  def test_real_embed_model_cdn_url_strategy_respects_artifacts_enabled
    source = File.read(File.expand_path("../app/models/recording_studio_embeddable/embed.rb", __dir__))

    assert_includes source, "Cdn.enabled?"
    assert_includes source, "def cdn_url_strategy?"
  end

  private

  def build_cdn_embed
    FakeEmbed.new(token: "hostfallbacktoken123456789012").tap do |embed|
      embed.metadata = {
        "artifact" => {
          "id" => "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
          "public_url" => "https://artifacts.example.test/recording_studio_artifacts/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
          "published_at" => Time.now.utc.iso8601
        }
      }
    end
  end
end
