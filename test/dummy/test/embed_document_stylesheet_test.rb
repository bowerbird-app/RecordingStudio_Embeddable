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

  test "stylesheet digest changes the public cache key" do
    controller = RecordingStudioEmbeddable::EmbedsController.new
    controller.instance_variable_set(:@embed, "embed")
    controller.instance_variable_set(:@parent_recording, "recording")
    controller.instance_variable_set(:@parent_recordable, "recordable")
    controller.instance_variable_set(:@options, {})
    klass = RecordingStudioEmbeddable::EmbedStylesheet
    original = klass.method(:digest)
    klass.define_singleton_method(:digest) { "digest-aaa" }
    first = controller.send(:cache_key_parts)
    klass.define_singleton_method(:digest) { "digest-bbb" }
    second = controller.send(:cache_key_parts)

    assert_includes first, "digest-aaa"
    assert_includes second, "digest-bbb"
    refute_equal first, second
  ensure
    klass.define_singleton_method(:digest, original) if klass && original
  end
end
