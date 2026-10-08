# frozen_string_literal: true

require "test_helper"

class ArtifactsEnabledIntegrationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @storage = RecordingStudioArtifacts.configuration.cdn_storage
    @storage.clear! if @storage.respond_to?(:clear!)
    RecordingStudioArtifacts.configuration.cdn_public_base_url = "https://artifacts.example.test"
    RecordingStudioEmbeddable.configuration.require_publishable = false
    RecordingStudioEmbeddable.configuration.allow_any_domain = true
  end

  teardown do
    RecordingStudioEmbeddable.configuration.artifacts_enabled = false
    RecordingStudioEmbeddable.configuration.require_publishable = true
    clear_enqueued_jobs
  end

  test "artifacts off keeps host rails urls and does not enqueue publish" do
    RecordingStudioEmbeddable.configuration.artifacts_enabled = false
    embed = RecordingStudioEmbeddable::Embed.create!(
      enabled: true,
      embed_url_strategy: "cdn",
      metadata: {
        "artifact" => {
          "id" => "11111111-2222-3333-4444-555555555555",
          "public_url" => "https://artifacts.example.test/recording_studio_artifacts/11111111-2222-3333-4444-555555555555",
          "published_at" => Time.now.utc.iso8601
        }
      }
    )

    assert_equal "/recording_studio_embeddable/embeds/#{embed.token}", embed.public_path
    assert_no_enqueued_jobs(only: RecordingStudioEmbeddable::PublishEmbedToCdnJob) do
      embed.enqueue_cdn_publish!
    end
  end

  test "artifacts on returns cdn urls and enqueues publish" do
    RecordingStudioEmbeddable.configuration.artifacts_enabled = true
    embed = RecordingStudioEmbeddable::Embed.create!(
      enabled: true,
      embed_url_strategy: "cdn"
    )

    assert_enqueued_with(job: RecordingStudioEmbeddable::PublishEmbedToCdnJob, args: [embed.id]) do
      embed.enqueue_cdn_publish!
    end

    result = RecordingStudioEmbeddable::Services::PublishEmbedToCdn.call(
      embed: embed,
      synchronous: true
    )
    assert result.success?, result.error.to_s
    embed = RecordingStudioEmbeddable::Embed.find(embed.id)
    assert_includes embed.public_url, "recording_studio_artifacts/"
  end
end
