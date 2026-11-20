# frozen_string_literal: true

require "test_helper"

class RendererAssignsTest < Minitest::Test
  class Recordable
    def self.recording_studio_embeddable_options
      { renderer: "pages/embed", enabled: true }
    end

    def self.model_name
      @model_name ||= ActiveModel::Name.new(self, nil, "Page")
    end

    def model_name
      self.class.model_name
    end
  end

  ContentRecording = Struct.new(:recordable)
  EmbedRecording = Struct.new(:parent_recording)
  EmbedRow = Struct.new(:recording)

  def test_host_template_variables_use_the_embedded_recording
    page = Recordable.new
    content = ContentRecording.new(page)
    embed_recording = EmbedRecording.new(content)
    embed = EmbedRow.new(embed_recording)

    assigns = RecordingStudioEmbeddable::Renderer.assigns_for(
      embed,
      theme: { accent_color: "#111111" }
    )

    assert_equal embed_recording, assigns[:recording]
    assert_equal content, assigns[:parent_recording]
    assert_equal page, assigns[:parent_recordable]
    assert_equal page, assigns[:recordable]
    assert_equal page, assigns[:page]
    assert_equal embed, assigns[:embed]
    assert_equal "pages/embed", assigns[:options][:renderer]
    assert_equal "#111111", assigns[:embed_theme][:accent_color]
  end

  def test_passed_recording_fills_in_when_the_embed_has_no_recording
    page = Recordable.new
    content = ContentRecording.new(page)
    embed = Object.new
    target = Object.new

    RecordingStudioEmbeddable::Renderer.apply_template_variables(
      target,
      embed,
      recording: content,
      theme: {}
    )

    assert_equal content, target.instance_variable_get(:@recording)
    assert_equal content, target.instance_variable_get(:@parent_recording)
    assert_equal page, target.instance_variable_get(:@page)
    assert_equal({}, target.instance_variable_get(:@embed_theme))
  end
end
