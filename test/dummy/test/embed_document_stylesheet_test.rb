# frozen_string_literal: true

require "test_helper"

class EmbedDocumentStylesheetTest < ActionDispatch::IntegrationTest
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

  test "rendered embed inlines theme css and does not link the host origin" do
    get "/recording_studio_embeddable/embeds/missing-token-does-not-exist"

    assert_response :not_found
    body = response.body
    digest = RecordingStudioEmbeddable::EmbedStylesheet.digest

    assert_includes body, "--surface-background-color"
    assert_includes body, 'data-theme="rounded"'
    assert_includes body, %(data-stylesheet-digest="#{digest}")
    assert_includes body, "recording-studio-embeddable-stylesheet: #{digest}"
    refute_includes body, "importmap"
    refute_match(%r{<script\b[^>]*\ssrc=}i, body)

    body.scan(/<link\b[^>]*>/i).each do |tag|
      href = tag[/href="([^"]+)"/, 1].to_s
      next if href.include?("fonts.googleapis.com") || href.include?("fonts.gstatic.com")

      flunk "embed document linked a host stylesheet: #{tag}"
    end
  end
end
