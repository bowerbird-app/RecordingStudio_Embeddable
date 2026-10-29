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
    assert_includes error.message, "Known sandbox tokens"
    assert_includes error.message, "allow-scripts"
    assert_equal previous, RecordingStudioEmbeddable.configuration.floating_defaults
    refute previous.key?("sandbox")
  end

  def test_floating_defaults_assignment_rejects_allow_origin_lists
    offending = "clipboard-write=(self)"
    error = assert_raises(ArgumentError) do
      RecordingStudioEmbeddable.configuration.floating_defaults = { "allow" => offending }
    end

    assert_includes error.message, "bare feature"
    assert_includes error.message, %(Offending token: "#{offending}".)
  end

  def test_uppercase_allow_feature_is_an_unknown_token
    error = assert_raises(ArgumentError) { register(allow: "Camera") }

    assert_includes error.message, %(Unknown allow token "Camera")
    assert_includes error.message, "Known allow tokens"
    assert_includes error.message, "clipboard-write"
    refute_includes error.message, "Origin lists"
    refute_includes error.message, "Offending token"
  end

  def test_nil_floating_defaults_and_floating_options_must_be_a_hash
    defaults_error = assert_raises(ArgumentError) do
      RecordingStudioEmbeddable.configuration.floating_defaults = nil
    end
    assert_includes defaults_error.message, "floating_defaults must be a hash."

    options_error = assert_raises(ArgumentError) do
      RecordingStudio::Capabilities::Embeddable.to(floating: true, floating_options: nil)
    end
    assert_includes options_error.message, "floating_options must be a hash."
  end

  def test_mutation_after_validation_raises_frozen_error
    RecordingStudioEmbeddable.configuration.floating_defaults = {
      sandbox: "allow-scripts",
      allow: "clipboard-write"
    }
    defaults = RecordingStudioEmbeddable.configuration.floating_defaults

    assert_raises(FrozenError) { defaults[:sandbox] << " allow-popups" }
    assert_raises(FrozenError) { defaults[:allow] = "fullscreen" }
    assert_raises(FrozenError) { defaults["sandbox"] = "allow-forms" }
    assert_equal "allow-scripts", defaults[:sandbox]
    assert_equal "clipboard-write", defaults[:allow]

    capability = register(sandbox: "allow-scripts", allow: "clipboard-write")
    options = capability.options[:floating_options]

    assert_raises(FrozenError) { options[:allow] = "fullscreen" }
    assert_raises(FrozenError) { options[:sandbox] << " allow-popups" }
    assert_raises(FrozenError) { capability.options[:floating_options] = { sandbox: "allow-forms" } }
    assert_equal "allow-scripts", options[:sandbox]
    assert_equal "clipboard-write", options[:allow]
  end

  def test_type_registration_rejects_unknown_tokens
    error = assert_raises(ArgumentError) do
      register(sandbox: "allow-scripts allow-evil")
    end
    assert_includes error.message, "allow-evil"
    assert_includes error.message, "Known sandbox tokens"
    assert_includes error.message, "allow-scripts"

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
    assert_includes error.message, %(Offending token: "'self'".)
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
    if floating_options
      layer = { floating_options: floating_options }
      RecordingStudioEmbeddable::Floating::PopupFrame.normalize_floating_options!(layer)
      options[:floating_options] = layer.fetch(:floating_options)
    end
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
