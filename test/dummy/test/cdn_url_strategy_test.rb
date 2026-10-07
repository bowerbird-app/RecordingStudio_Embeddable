# frozen_string_literal: true

require "test_helper"

class CdnUrlStrategyTest < ActiveSupport::TestCase
  setup do
    @storage = RecordingStudioEmbeddable::Cdn::MemoryStorage.new
    RecordingStudioEmbeddable.configuration.cdn_storage = @storage
    RecordingStudioEmbeddable.configuration.cdn_purger = @storage
    RecordingStudioEmbeddable.configuration.cdn_public_base_url = "https://embeds.example.test"
  end

  test "dummy initializer exposes CDN public base for partner URLs" do
    assert_equal "https://embeds.example.test",
                 RecordingStudioEmbeddable::Cdn.public_base_url
    assert RecordingStudioEmbeddable.configuration.cdn_storage.present?
  end

  test "cdn strategy helpers never paste rails mount into partner snippets" do
    embed = RecordingStudioEmbeddable::Embed.create!(
      enabled: true,
      embed_url_strategy: "cdn",
      allowed_embedder_domains: []
    )

    assert_equal "/embeds/#{embed.token}.html", embed.public_path
    assert_equal "https://embeds.example.test/embeds/#{embed.token}.html", embed.public_url
    refute_includes embed.public_url, "recording_studio_embeddable"
  end

  test "publish overwrites the same object key on update" do
    RecordingStudioEmbeddable.configuration.require_publishable = false
    RecordingStudioEmbeddable.configuration.allow_any_domain = true

    embed = RecordingStudioEmbeddable::Embed.create!(
      enabled: false,
      embed_url_strategy: "cdn"
    )

    first = RecordingStudioEmbeddable::Services::PublishEmbedToCdn.call(
      embed: embed,
      storage: @storage,
      purger: @storage
    )
    assert first.success?, first.error
    key = embed.cdn_object_key
    assert_equal key, first.value[:key]
    first_body = @storage.read(key)[:body]

    # Recordables are readonly after create; flip enabled without revise for this publish proof.
    RecordingStudioEmbeddable::Embed.where(id: embed.id).update_all(enabled: true)
    embed = RecordingStudioEmbeddable::Embed.find(embed.id)

    second = RecordingStudioEmbeddable::Services::PublishEmbedToCdn.call(
      embed: embed,
      storage: @storage,
      purger: @storage
    )
    # Still unavailable without parent recording — body may match unavailable stub —
    # but the object key and partner URL stay identical.
    assert second.success?, second.error
    assert_equal key, second.value[:key]
    assert_equal first.value[:public_url], second.value[:public_url]
    assert_equal 1, @storage.objects.size
    assert_equal 2, @storage.purges.size
    assert_includes first_body, "Embed unavailable"
  end
end
