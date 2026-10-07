# frozen_string_literal: true

require "test_helper"

class CdnUrlStrategyTest < ActiveSupport::TestCase
  setup do
    @storage = RecordingStudioArtifacts.configuration.cdn_storage
    @storage.clear! if @storage.respond_to?(:clear!)
    RecordingStudioArtifacts.configuration.cdn_public_base_url = "https://artifacts.example.test"
    RecordingStudioEmbeddable.configuration.require_publishable = false
    RecordingStudioEmbeddable.configuration.allow_any_domain = true
  end

  test "dummy wires Artifacts MemoryStorage for CDN publish" do
    assert RecordingStudioArtifacts::Cdn.public_base_configured?
    assert_kind_of RecordingStudioArtifacts::Cdn::MemoryStorage,
                   RecordingStudioArtifacts.configuration.cdn_storage
  end

  test "cdn strategy returns Artifacts public URL after publish" do
    embed = RecordingStudioEmbeddable::Embed.create!(
      enabled: false,
      embed_url_strategy: "cdn",
      allowed_embedder_domains: []
    )

    result = RecordingStudioEmbeddable::Services::PublishEmbedToCdn.call(
      embed: embed,
      synchronous: true
    )
    assert result.success?, result.error.to_s

    embed = RecordingStudioEmbeddable::Embed.find(embed.id)
    assert embed.cdn_published?
    assert_equal result.value[:public_url], embed.public_url
    assert_includes embed.public_url, "recording_studio_artifacts/"
    refute_includes embed.public_url, "recording_studio_embeddable"
    assert_equal URI.parse(embed.public_url).path, embed.public_path
  end

  test "re-publish updates the same Artifacts URL" do
    embed = RecordingStudioEmbeddable::Embed.create!(
      enabled: false,
      embed_url_strategy: "cdn"
    )

    first = RecordingStudioEmbeddable::Services::PublishEmbedToCdn.call(
      embed: embed,
      synchronous: true
    )
    assert first.success?, first.error.to_s
    artifact_id = first.value[:artifact_id]
    public_url = first.value[:public_url]

    RecordingStudioEmbeddable::Embed.where(id: embed.id).update_all(enabled: true)
    embed = RecordingStudioEmbeddable::Embed.find(embed.id)

    second = RecordingStudioEmbeddable::Services::PublishEmbedToCdn.call(
      embed: embed,
      synchronous: true
    )
    assert second.success?, second.error.to_s
    assert_equal artifact_id, second.value[:artifact_id]
    assert_equal public_url, second.value[:public_url]
    assert_equal 1, @storage.objects.size
    assert_includes @storage.read("recording_studio_artifacts/#{artifact_id}")[:body], "Embed unavailable"
  end
end
