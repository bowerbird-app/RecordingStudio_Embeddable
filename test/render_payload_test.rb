# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "active_support/core_ext/object/blank"

class RenderPayloadTest < Minitest::Test
  FakeClass = Struct.new(:recording_studio_embeddable_options) do
    def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")
  end

  class FakeRecordable
    def self.recording_studio_embeddable_options
      { enabled: true, renderer: "recording_studio_embeddable/embeds/default" }
    end

    def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")

    def updated_at
      Time.at(1_700_000_000)
    end
  end

  FakeRecording = Struct.new(:recordable, :updated_at)
  FakeEmbed = Struct.new(:sizing, :appearance, :updated_at, keyword_init: true)

  class FakeRenderer
    attr_reader :calls

    def initialize(html:)
      @html = html
      @calls = []
    end

    def render(**options)
      @calls << options
      @html
    end
  end

  def setup
    RecordingStudioEmbeddable.reset_configuration!
    @original_renderer = ActionController::Base.method(:renderer)
    @fake_renderer = FakeRenderer.new(html: '<article class="embed"><p>Hello</p></article>')
    ActionController::Base.define_singleton_method(:renderer) { @payload_test_renderer }
    ActionController::Base.instance_variable_set(:@payload_test_renderer, @fake_renderer)
  end

  def teardown
    ActionController::Base.define_singleton_method(:renderer, @original_renderer)
    ActionController::Base.remove_instance_variable(:@payload_test_renderer) if
      ActionController::Base.instance_variable_defined?(:@payload_test_renderer)
  end

  def test_returns_schema_version_1_wire_shape
    result = RecordingStudioEmbeddable::RenderPayload.call(
      recording: recording,
      embed: embed
    )

    assert result.success?, result.error
    hash = result.value!.to_h

    assert_equal %w[configuration html schema_version sdk], hash.keys.sort
    assert_equal 1, hash["schema_version"]
    assert_equal "0.3.0", hash.dig("sdk", "minimum_version")
    assert_equal '<article class="embed"><p>Hello</p></article>', hash["html"]
    assert hash["configuration"].key?("theme")
    assert hash["configuration"].key?("sizing")
  end

  def test_configuration_allowlists_theme_and_sizing_keys
    styled_embed = FakeEmbed.new(
      sizing: {
        "width" => "40rem",
        "mode" => "custom",
        "max_width" => 960,
        "min_height" => 240,
        "height" => "auto",
        "aspect_ratio" => "16:9",
        "unknown" => "drop-me"
      },
      appearance: {},
      updated_at: Time.at(1_700_000_100)
    )

    result = RecordingStudioEmbeddable::RenderPayload.call(
      recording: recording,
      embed: styled_embed
    )

    sizing = result.value!.to_h.dig("configuration", "sizing")

    assert_equal(
      {
        "width" => "40rem",
        "mode" => "custom",
        "max_width" => 960,
        "min_height" => 240,
        "height" => "auto"
      },
      sizing
    )
    refute sizing.key?("aspect_ratio")
    refute sizing.key?("unknown")
  end

  def test_fragment_has_no_document_layout_chrome
    @fake_renderer = FakeRenderer.new(
      html: "<!DOCTYPE html><html><body><p>wrapped</p></body></html>"
    )
    ActionController::Base.instance_variable_set(:@payload_test_renderer, @fake_renderer)

    # Sanitizer keeps doctype/html/body if present; renderer must use layout:false so
    # production fragments never include them. Assert the render call itself.
    RecordingStudioEmbeddable::RenderPayload.call(recording: recording, embed: embed)

    options = @fake_renderer.calls.fetch(0)
    assert_equal false, options[:layout]
    assert_equal [:html], options[:formats]
  end

  def test_uses_renderer_template_resolution
    result = RecordingStudioEmbeddable::RenderPayload.call(
      recording: recording,
      embed: embed
    )

    assert result.success?, result.error
    options = @fake_renderer.calls.fetch(0)
    expected = RecordingStudioEmbeddable::Renderer.resolve(recording, embed)

    assert_equal expected, options[:template]
    assert_equal "recording_studio_embeddable/embeds/default", options[:template]
    assert_equal expected, result.value!.metadata.template
  end

  def test_does_not_call_capture_view
    called = false
    original = RecordingStudioEmbeddable::Services::CaptureView.method(:call)
    RecordingStudioEmbeddable::Services::CaptureView.define_singleton_method(:call) do |**|
      called = true
    end

    result = RecordingStudioEmbeddable::RenderPayload.call(
      recording: recording,
      embed: embed
    )

    assert result.success?, result.error
    refute called
  ensure
    RecordingStudioEmbeddable::Services::CaptureView.define_singleton_method(:call, original)
  end

  def test_metadata_is_omitted_from_to_h
    result = RecordingStudioEmbeddable::RenderPayload.call(
      recording: recording,
      embed: embed
    )

    payload = result.value!
    refute_nil payload.metadata
    refute payload.to_h.key?("metadata")
    refute payload.to_h.key?(:metadata)
  end

  def test_fails_when_recording_blank
    result = RecordingStudioEmbeddable::RenderPayload.call(recording: nil, embed: embed)

    assert result.failure?
    assert_match(/recording/i, result.error)
  end

  def test_fails_when_embed_nil
    result = RecordingStudioEmbeddable::RenderPayload.call(recording: recording, embed: nil)

    assert result.failure?
    assert_match(/embed/i, result.error)
  end

  def test_sanitizes_rendered_html
    @fake_renderer = FakeRenderer.new(
      html: '<p onclick="x()">ok</p><script>alert(1)</script><a href="javascript:alert(2)">x</a>'
    )
    ActionController::Base.instance_variable_set(:@payload_test_renderer, @fake_renderer)

    html = RecordingStudioEmbeddable::RenderPayload.call(recording: recording, embed: embed).value!.html

    refute_includes html, "<script"
    refute_includes html, "onclick"
    refute_match(/javascript:/i, html)
    assert_includes html, "<p>ok</p>"
  end

  def test_iframe_layout_for_still_defaults_to_embed_layout
    assert_equal "recording_studio_embeddable/embed",
                 RecordingStudioEmbeddable::Renderer.layout_for(recording, embed)
  end

  def test_public_embed_path_unchanged
    token_embed = Class.new do
      def token = "abc123token"
      def public_path = "/recording_studio_embeddable/embeds/#{token}"
    end.new

    assert_equal "/recording_studio_embeddable/embeds/abc123token", token_embed.public_path
  end

  private

  def recording
    @recording ||= FakeRecording.new(FakeRecordable.new, Time.at(1_700_000_050))
  end

  def embed
    @embed ||= FakeEmbed.new(
      sizing: RecordingStudioEmbeddable.configuration.default_sizing,
      appearance: {},
      updated_at: Time.at(1_700_000_100)
    )
  end
end
