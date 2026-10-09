# frozen_string_literal: true

require "test_helper"

class PublicEmbedNotFoundTest < ActionDispatch::IntegrationTest
  setup do
    RecordingStudioEmbeddable.configuration.public_embeds_enabled = true
    RecordingStudioEmbeddable.configuration.allow_any_domain = true
    RecordingStudioEmbeddable.configuration.require_publishable = false
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = false
  end

  teardown do
    RecordingStudioEmbeddable.configuration.require_publishable = true
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = true
  end

  test "invalid token renders flatpack empty state with 404" do
    get "/recording_studio_embeddable/embeds/missing-token-does-not-exist"

    assert_response :not_found
    assert_includes response.body, "Oops"
    assert_includes response.body, "This embed is gone, or the link is wrong"
    assert_includes response.body, "fp-empty-state"
    assert_includes response.body, "exclamation-circle"
    assert_equal "frame-ancestors 'none'", response.headers["Content-Security-Policy"]
    refute_includes response.body, "disabled"
    refute_includes response.body, "unpublished"
    refute_includes response.body, "invalid_token"
    refute_includes response.body, "Embed not available"
  end

  test "disabled embed renders the same generic empty state" do
    embed = RecordingStudioEmbeddable::Embed.create!(enabled: false)

    get "/recording_studio_embeddable/embeds/#{embed.token}"

    assert_response :not_found
    assert_includes response.body, "Oops"
    assert_includes response.body, "fp-empty-state"
    assert_includes response.body, "exclamation-circle"
    refute_includes response.body, "disabled"
    refute_includes response.body, "Embed not available"
  end
end
