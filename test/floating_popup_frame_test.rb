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

  def test_registration_stores_canonical_strings_and_render_uses_them
    from_array = register(
      sandbox: %w[allow-scripts allow-same-origin allow-forms allow-popups],
      allow: [:"clipboard-write"]
    )
    from_string = register(sandbox: CHATKIT_SANDBOX, allow: "clipboard-write")

    assert_equal CHATKIT_SANDBOX, from_array.options[:floating_options][:sandbox]
    assert_equal "clipboard-write", from_array.options[:floating_options][:allow]
    assert_equal rendered(from_string), rendered(from_array)
    assert_equal({ "sandbox" => CHATKIT_SANDBOX, "allow" => "clipboard-write" }, rendered(from_string))
    fullscreen = register(allow: %w[clipboard-write fullscreen])
    assert_equal "clipboard-write; fullscreen", fullscreen.options[:floating_options][:allow]
    assert_equal(
      "allow-popups-to-escape-sandbox",
      register(sandbox: "allow-popups-to-escape-sandbox").options[:floating_options][:sandbox]
    )
  end

  def test_capability_options_replace_app_defaults_for_that_key
    RecordingStudioEmbeddable.configuration.floating_defaults = {
      "sandbox" => "allow-forms",
      "allow" => "fullscreen"
    }
    replaced = rendered(register(sandbox: "allow-scripts"))

    assert_equal "allow-scripts", replaced.fetch("sandbox")
    assert_equal "fullscreen", replaced.fetch("allow")

    allow_only = rendered(register(allow: "clipboard-write"))
    assert_equal "allow-forms", allow_only.fetch("sandbox")
    assert_equal "clipboard-write", allow_only.fetch("allow")
    assert_equal "allow-forms", RecordingStudioEmbeddable.configuration.floating_defaults.fetch("sandbox")
    assert_equal "fullscreen", RecordingStudioEmbeddable.configuration.floating_defaults.fetch("allow")
  end

  def test_floating_defaults_assignment_rejects_unknown_sandbox
    previous = RecordingStudioEmbeddable.configuration.floating_defaults
    error = assert_raises(ArgumentError) do
      RecordingStudioEmbeddable.configuration.floating_defaults = { "sandbox" => "allow-scripts allow-evil" }
    end

    assert_includes error.message, "allow-evil"
    assert_equal previous, RecordingStudioEmbeddable.configuration.floating_defaults
    refute previous.key?("sandbox")
  end

  def test_floating_defaults_assignment_rejects_allow_origin_lists
    error = assert_raises(ArgumentError) do
      RecordingStudioEmbeddable.configuration.floating_defaults = { "allow" => "camera 'self'" }
    end

    assert_includes error.message, "bare feature"
    assert_includes error.message, "camera 'self'"
  end

  def test_type_registration_rejects_unknown_tokens
    error = assert_raises(ArgumentError) do
      register(sandbox: "allow-scripts allow-evil")
    end
    assert_includes error.message, "allow-evil"

    allow_error = assert_raises(ArgumentError) { register(allow: "clipboard") }
    assert_includes allow_error.message, "clipboard"
    assert_includes allow_error.message, "clipboard-write"

    assert_raises(ArgumentError) { register(sandbox: "") }
    assert_raises(ArgumentError) { register(sandbox: []) }
    assert_raises(ArgumentError) { register(allow: "   ") }
    assert_raises(ArgumentError) { register(sandbox: "allow-scripts allow-scripts") }
    assert_raises(ArgumentError) { register(sandbox: 12) }
    assert_raises(ArgumentError) { register(allow: [12]) }
    assert_raises(ArgumentError) { register(sandbox: nil) }
  end

  def test_recordable_macro_rejects_invalid_floating_options
    klass = Class.new
    klass.include RecordingStudioEmbeddable::Recordable

    error = assert_raises(ArgumentError) do
      klass.recording_studio_embeddable(floating_options: { allow: "camera 'self'" })
    end

    assert_includes error.message, "bare feature"
  end

  def test_render_reads_stored_strings_without_validating
    rendered = RecordingStudioEmbeddable::Floating::PopupFrame.for(
      recording_with(floating_options: { sandbox: "allow-evil", allow: "camera 'self'" })
    )

    assert_equal "allow-evil", rendered.fetch("sandbox")
    assert_equal "camera 'self'", rendered.fetch("allow")
  end

  private

  def register(sandbox: :unset, allow: :unset)
    options = {}
    options[:sandbox] = sandbox unless sandbox == :unset
    options[:allow] = allow unless allow == :unset
    RecordingStudio::Capabilities::Embeddable.to(floating: true, floating_options: options)
  end

  def rendered(capability)
    RecordingStudioEmbeddable::Floating::PopupFrame.for(
      recording_with(floating_options: capability.options[:floating_options])
    )
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
