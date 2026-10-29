# frozen_string_literal: true

require "test_helper"

class FloatingPopupFrameTest < Minitest::Test
  CHATKIT_SANDBOX = "allow-scripts allow-same-origin allow-forms allow-popups"

  def setup
    RecordingStudioEmbeddable.reset_configuration!
  end

  def teardown
    RecordingStudioEmbeddable.reset_configuration!
  end

  def test_unset_options_omit_sandbox_and_allow
    assert_equal({}, RecordingStudioEmbeddable::Floating::PopupFrame.for(recording_with))
  end

  def test_string_and_array_render_the_same_sandbox_and_allow
    from_string = frame_for(
      sandbox: CHATKIT_SANDBOX,
      allow: "clipboard-write"
    )
    from_array = frame_for(
      sandbox: %w[allow-scripts allow-same-origin allow-forms allow-popups],
      allow: [:"clipboard-write"]
    )

    assert_equal({ "sandbox" => CHATKIT_SANDBOX, "allow" => "clipboard-write" }, from_string)
    assert_equal from_string, from_array
    assert_equal "clipboard-write", frame_for(allow: :"clipboard-write").fetch("allow")
    assert_equal "clipboard-write; fullscreen", frame_for(allow: %w[clipboard-write fullscreen]).fetch("allow")
    assert_equal "allow-popups-to-escape-sandbox", frame_for(sandbox: "allow-popups-to-escape-sandbox").fetch("sandbox")
  end

  def test_capability_options_replace_app_defaults_for_that_key
    RecordingStudioEmbeddable.configuration.floating_defaults = {
      "sandbox" => "allow-forms",
      "allow" => "fullscreen"
    }
    replaced = frame_for(sandbox: "allow-scripts")

    assert_equal "allow-scripts", replaced.fetch("sandbox")
    assert_equal "fullscreen", replaced.fetch("allow")

    allow_only = frame_for(allow: "clipboard-write")
    assert_equal "allow-forms", allow_only.fetch("sandbox")
    assert_equal "clipboard-write", allow_only.fetch("allow")
  end

  def test_unknown_sandbox_token_raises
    error = assert_raises(ArgumentError) do
      frame_for(sandbox: "allow-scripts allow-evil")
    end

    assert_includes error.message, "allow-evil"
    assert_includes error.message, "allow-scripts"
  end

  def test_unknown_allow_feature_raises
    error = assert_raises(ArgumentError) { frame_for(allow: "clipboard") }

    assert_includes error.message, "clipboard"
    assert_includes error.message, "clipboard-write"
  end

  def test_blank_repeated_and_non_token_values_raise
    assert_raises(ArgumentError) { frame_for(sandbox: "") }
    assert_raises(ArgumentError) { frame_for(sandbox: []) }
    assert_raises(ArgumentError) { frame_for(allow: "   ") }
    assert_raises(ArgumentError) { frame_for(sandbox: "allow-scripts allow-scripts") }
    assert_raises(ArgumentError) { frame_for(sandbox: 12) }
    assert_raises(ArgumentError) { frame_for(allow: [12]) }
    assert_raises(ArgumentError) { frame_for(sandbox: nil) }
  end

  private

  def frame_for(sandbox: :unset, allow: :unset)
    options = {}
    options[:sandbox] = sandbox unless sandbox == :unset
    options[:allow] = allow unless allow == :unset
    RecordingStudioEmbeddable::Floating::PopupFrame.for(recording_with(floating_options: options))
  end

  def recording_with(floating_options: nil)
    options = { enabled: true, floating: true }
    options[:floating_options] = floating_options if floating_options
    recording = Object.new
    recordable = recordable_with(options)
    recording.define_singleton_method(:recordable) { recordable }
    recording
  end

  def recordable_with(options)
    klass = Class.new do
      class << self
        attr_accessor :options_for_test
      end

      define_singleton_method(:recording_studio_embeddable_options) { options_for_test }
    end
    klass.options_for_test = options
    klass.new
  end
end
