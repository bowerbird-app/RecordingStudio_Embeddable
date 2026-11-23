# frozen_string_literal: true

require "test_helper"
require "action_controller"

class ApiTest < Minitest::Test
  ActionContext = Struct.new(:recording, :access_grant, :params, :actor, keyword_init: true)

  class AccessGrant
    attr_reader :authorized_recordings

    def initialize
      @authorized_recordings = []
    end

    def authorize!(recording:, role:)
      authorized_recordings << [recording, role]
    end
  end

  FakeEmbed = Struct.new(:sizing, :appearance, :updated_at, keyword_init: true)

  class FakeRecordable
    def self.recording_studio_embeddable_options
      { enabled: true, renderer: "recording_studio_embeddable/embeds/default" }
    end

    def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")
  end

  FakeRecording = Struct.new(:recordable, :updated_at, :embed, keyword_init: true) do
    def ensure_embed!(**)
      embed
    end
  end

  class FakeRenderer
    def render(**)
      "<p>payload</p>"
    end
  end

  def setup
    RecordingStudioEmbeddable.reset_configuration!
    @original_renderer = ActionController::Base.method(:renderer)
    ActionController::Base.instance_variable_set(:@payload_test_renderer, FakeRenderer.new)
    ActionController::Base.define_singleton_method(:renderer) { @payload_test_renderer }
  end

  def teardown
    ActionController::Base.define_singleton_method(:renderer, @original_renderer)
    ActionController::Base.remove_instance_variable(:@payload_test_renderer) if
      ActionController::Base.instance_variable_defined?(:@payload_test_renderer)
    Object.send(:remove_const, :RecordingStudioApi) if Object.const_defined?(:RecordingStudioApi, false)
    RecordingStudioEmbeddable::Api::OpenapiOverrides.reset!
  end

  def test_descriptor_matches_embed_capability_action
    descriptor = RecordingStudioEmbeddable::Api.descriptor

    assert_equal :embed, descriptor[:name]
    assert_equal :embeddable, descriptor[:capability]
    assert_equal :get, descriptor[:http_verb]
    assert_equal :member, descriptor[:scope]
    assert_equal :edit, descriptor[:required_role]
    assert_equal "RecordingStudioEmbeddable::Api::EmbedRecording", descriptor[:handler]
  end

  def test_registration_is_a_noop_without_recording_studio_api
    refute Object.const_defined?(:RecordingStudioApi, false)

    assert_nil RecordingStudioEmbeddable::Api.register_capability_action!
  end

  def test_registration_registers_embeddable_owned_member_action
    with_fake_recording_studio_api do |api|
      RecordingStudioEmbeddable::Api.register_capability_action!

      registration = api.registrations.fetch(0)

      assert_equal :embed, registration.fetch(:name)
      assert_equal :embeddable, registration.fetch(:capability)
      assert_equal :get, registration.fetch(:http_verb)
      assert_equal :member, registration.fetch(:scope)
      assert_equal :edit, registration.fetch(:required_role)
      assert_equal RecordingStudioEmbeddable::Api::EmbedRecording, registration.fetch(:handler)
      assert_equal RecordingStudioEmbeddable::Api::ACTION_SUMMARY, registration.fetch(:openapi).fetch(:summary)
      assert_equal RecordingStudioEmbeddable::Api::ACTION_RESPONSE_DESCRIPTIONS.fetch("403"),
                   registration.fetch(:openapi).fetch(:responses).fetch("403").fetch(:description)
    end
  end

  def test_registration_does_not_replace_an_existing_embed_action
    with_fake_recording_studio_api(existing_action: Object.new) do |api|
      assert_nil RecordingStudioEmbeddable::Api.register_capability_action!
      assert_empty api.registrations
    end
  end

  def test_override_openapi_applies_to_one_type
    press_center = "RecordingStudioPressCenters::PressCenter"

    RecordingStudioEmbeddable::Api.override_openapi(
      type: press_center,
      action: :embed,
      title: "Embed press center",
      description: "Place this press center on another page."
    )

    press = RecordingStudioEmbeddable::Api.openapi_for(type: press_center, action: :embed)
    page = RecordingStudioEmbeddable::Api.openapi_for(type: "Page", action: :embed)

    assert_equal "Embed press center", press.fetch(:title)
    assert_equal "Place this press center on another page.", press.fetch(:description)
    assert_equal RecordingStudioEmbeddable::Api::ACTION_SUMMARY, press.fetch(:summary)
    assert_equal RecordingStudioEmbeddable::Api::ACTION_RESPONSE_DESCRIPTIONS.fetch("200"),
                 press.fetch(:responses).fetch("200").fetch(:description)
    refute page.key?(:title)
    assert_equal RecordingStudioEmbeddable::Api::ACTION_SUMMARY, page.fetch(:summary)
    assert_equal RecordingStudioEmbeddable::Api::ACTION_DESCRIPTION, page.fetch(:description)
    assert_equal press.fetch(:responses), page.fetch(:responses)
  end

  def test_override_openapi_keeps_the_default_description_when_omitted
    press_center = Class.new

    RecordingStudioEmbeddable::Api.override_openapi(
      type: press_center,
      action: "embed",
      title: "Embed press center"
    )

    press = RecordingStudioEmbeddable::Api.openapi_for(type: press_center.to_s, action: :embed)

    assert_equal "Embed press center", press.fetch(:title)
    assert_equal RecordingStudioEmbeddable::Api::ACTION_DESCRIPTION, press.fetch(:description)
  end

  def test_override_openapi_rejects_unknown_action_and_blank_title
    assert_raises(ArgumentError) do
      RecordingStudioEmbeddable::Api.override_openapi(type: "Page", action: :publish, title: "Publish page")
    end
    assert_raises(ArgumentError) do
      RecordingStudioEmbeddable::Api.override_openapi(type: "Page", action: 1, title: "Embed page")
    end
    assert_raises(ArgumentError) do
      RecordingStudioEmbeddable::Api.override_openapi(type: "Page", action: :embed, title: "  ")
    end
    assert_raises(ArgumentError) do
      RecordingStudioEmbeddable::Api.override_openapi(type: "Page", action: :embed, title: nil)
    end
    assert_raises(ArgumentError) do
      RecordingStudioEmbeddable::Api.override_openapi(type: "  ", action: :embed, title: "Embed page")
    end
    assert_raises(ArgumentError) do
      RecordingStudioEmbeddable::Api.openapi_for(type: "Page", action: :publish)
    end

    page = RecordingStudioEmbeddable::Api.openapi_for(type: "Page", action: :embed)

    refute page.key?(:title)
  end

  def test_registered_openapi_for_is_what_mcp_reads
    press_center = "RecordingStudioPressCenters::PressCenter"

    with_fake_recording_studio_api do |api|
      RecordingStudioEmbeddable::Api.register_capability_action!
      RecordingStudioEmbeddable::Api.override_openapi(
        type: press_center,
        action: :embed,
        title: "Embed press center"
      )

      registration = api.registrations.fetch(0)
      base = registration.fetch(:openapi)
      reader = registration.fetch(:openapi_for)
      press = reader.call(type: press_center, action: :embed)
      page = reader.call(type: "Page", action: :embed)
      merged = base.merge(press)

      refute base.key?(:title)
      assert_equal RecordingStudioEmbeddable::Api::ACTION_SUMMARY, base.fetch(:summary)
      assert_equal "Embed press center", press.fetch(:title)
      assert_equal "Embed press center", merged.fetch(:title)
      assert_equal RecordingStudioEmbeddable::Api::ACTION_DESCRIPTION, merged.fetch(:description)
      assert_equal base.fetch(:responses), merged.fetch(:responses)
      refute page.key?(:title)
      assert_equal RecordingStudioEmbeddable::Api.openapi_for(type: press_center, action: :embed), press
    end
  end

  def test_handler_returns_payload_hash_without_capture_view
    called = false
    original = RecordingStudioEmbeddable::Services::CaptureView.method(:call)
    RecordingStudioEmbeddable::Services::CaptureView.define_singleton_method(:call) do |**|
      called = true
    end

    access_grant = AccessGrant.new
    recording = FakeRecording.new(
      recordable: FakeRecordable.new,
      updated_at: Time.at(1_700_000_000),
      embed: FakeEmbed.new(
        sizing: { "width" => "100%", "height" => "auto" },
        appearance: {},
        updated_at: Time.at(1_700_000_000)
      )
    )

    with_fake_recording_studio_api do
      hash = RecordingStudioEmbeddable::Api::EmbedRecording.call(
        ActionContext.new(recording: recording, access_grant: access_grant, params: {})
      )

      assert_equal 1, hash.fetch("schema_version")
      assert_equal "<p>payload</p>", hash.fetch("html")
      assert_equal [[recording, :edit]], access_grant.authorized_recordings
      refute called
    end
  ensure
    RecordingStudioEmbeddable::Services::CaptureView.define_singleton_method(:call, original) if original
  end

  def test_handler_finds_or_creates_embed_with_context_actor
    actor = Object.new
    created = FakeEmbed.new(
      sizing: { "width" => "100%", "height" => "auto" },
      appearance: {},
      updated_at: Time.at(1_700_000_000)
    )
    recording = FakeRecording.new(
      recordable: FakeRecordable.new,
      updated_at: Time.at(1_700_000_000),
      embed: nil
    )
    passed_actor = nil
    recording.define_singleton_method(:ensure_embed!) do |actor: nil, **|
      passed_actor = actor
      created
    end

    with_fake_recording_studio_api do
      hash = RecordingStudioEmbeddable::Api::EmbedRecording.call(
        ActionContext.new(
          recording: recording,
          access_grant: AccessGrant.new,
          params: {},
          actor: actor
        )
      )

      assert_equal actor, passed_actor
      assert_equal 1, hash.fetch("schema_version")
    end
  end

  private

  def with_fake_recording_studio_api(existing_action: nil)
    api = Module.new
    api.instance_variable_set(:@existing_action, existing_action)
    api.instance_variable_set(:@registrations, [])
    api.define_singleton_method(:capability_action) { |name| @existing_action if name == :embed }
    api.define_singleton_method(:register_capability_action) do |name, **options|
      @registrations << options.merge(name:)
    end
    api.define_singleton_method(:registrations) { @registrations }
    api.const_set(:NotFoundError, Class.new(StandardError))
    api.const_set(:InvalidActionInputError, Class.new(StandardError) do
      attr_reader :details

      def initialize(message, details: [])
        super(message)
        @details = details
      end
    end)

    Object.const_set(:RecordingStudioApi, api)
    yield api
  ensure
    Object.send(:remove_const, :RecordingStudioApi) if Object.const_defined?(:RecordingStudioApi, false)
  end
end
