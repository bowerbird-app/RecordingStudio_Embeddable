# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"

class PublicEmbedNotFoundTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  RESPONSE_HEADERS = %w[
    Content-Security-Policy
    X-Frame-Options
    Cache-Control
    X-Content-Type-Options
    Referrer-Policy
    Permissions-Policy
    Vary
    Retry-After
    Content-Type
  ].freeze
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
    assert_no_view_log do
      get "/recording_studio_embeddable/embeds/missing-token-does-not-exist"
    end

    assert_response :not_found
    assert_includes response.body, "Oops"
    assert_includes response.body, "This embed is gone, or the link is wrong"
    assert_includes response.body, "fp-empty-state"
    assert_includes response.body, "exclamation-circle"
    assert_equal "frame-ancestors 'none'", response.headers["Content-Security-Policy"]
    refute_includes embed_markup, "disabled"
    refute_includes embed_markup, "unpublished"
    refute_includes embed_markup, "invalid_token"
    refute_includes embed_markup, "Embed not available"
  end

  test "disabled embed renders the same generic empty state" do
    embed = RecordingStudioEmbeddable::Embed.create!(enabled: false)

    assert_no_view_log do
      get "/recording_studio_embeddable/embeds/#{embed.token}"
    end

    assert_response :not_found
    assert_includes response.body, "Oops"
    assert_includes response.body, "fp-empty-state"
    assert_includes response.body, "exclamation-circle"
    refute_includes embed_markup, "disabled"
    refute_includes embed_markup, "Embed not available"
  end

  test "unknown and disabled token 404s match" do
    get "/recording_studio_embeddable/embeds/missing-token-byte-match"
    unknown_body = response.body
    unknown_headers = comparable_headers
    assert_response :not_found

    embed = RecordingStudioEmbeddable::Embed.create!(enabled: false)
    assert_no_view_log do
      get "/recording_studio_embeddable/embeds/#{embed.token}"
    end

    assert_response :not_found
    assert_equal unknown_body, response.body
    assert_equal unknown_headers, comparable_headers
    refute_includes response.body, embed.token
  end

  private

  def embed_markup
    response.body.gsub(%r{<style\b[^>]*>.*?</style>}m, "")
  end

  def comparable_headers
    RESPONSE_HEADERS.index_with { |name| response.headers[name] }
  end

  def assert_no_view_log(&)
    assert_no_difference -> { RecordingStudioEmbeddable::EmbeddableViewLog.count } do
      assert_no_enqueued_jobs only: RecordingStudioEmbeddable::LogViewJob, &
    end
  end
end
