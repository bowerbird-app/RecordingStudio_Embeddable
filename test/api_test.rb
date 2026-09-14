# frozen_string_literal: true

require "test_helper"
require "action_controller"

class ApiTest < Minitest::Test
  ActionContext = Struct.new(:recording, :access_grant, :params, keyword_init: true)

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

  FakeRecording = Struct.new(:recordable, :updated_at, :embed, keyword_init: true)

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
  end

  def test_descriptor_matches_embed_capability_action
    descriptor = RecordingStudioEmbeddable::Api.descriptor

    assert_equal :embed, descriptor[:name]
    assert_equal :embeddable, descriptor[:capability]
    assert_equal :get, descriptor[:http_verb]
    assert_equal :member, descriptor[:scope]
    assert_equal :read, descriptor[:required_role]
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
      assert_equal :read, registration.fetch(:required_role)
      assert_equal RecordingStudioEmbeddable::Api::EmbedRecording, registration.fetch(:handler)
      assert_equal "Embed", registration.fetch(:openapi).fetch(:summary)
    end
  end

  def test_registration_does_not_replace_an_existing_embed_action
    with_fake_recording_studio_api(existing_action: Object.new) do |api|
      assert_nil RecordingStudioEmbeddable::Api.register_capability_action!
      assert_empty api.registrations
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
      assert_equal [[recording, :read]], access_grant.authorized_recordings
      refute called
    end
  ensure
    RecordingStudioEmbeddable::Services::CaptureView.define_singleton_method(:call, original)
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
