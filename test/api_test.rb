# frozen_string_literal: true

require "test_helper"
require "action_controller"

class ApiTest < Minitest::Test
  ActionContext = Struct.new(:recording, :access_grant, :params, keyword_init: true)

  class AccessGrant
    attr_reader :authorized_recordings, :actor

    def initialize(actor: nil)
      @authorized_recordings = []
      @actor = actor
    end

    def authorize!(recording:, role:)
      authorized_recordings << [recording, role]
    end
  end

  FakeEmbed = Struct.new(:sizing, :appearance, :updated_at, keyword_init: true)

  class MutableEmbed
    attr_accessor :enabled, :sizing, :appearance, :updated_at, :persist_calls

    def initialize(enabled: false, sizing: {}, appearance: {}, updated_at: Time.at(1_700_000_000))
      @enabled = enabled
      @sizing = sizing
      @appearance = appearance
      @updated_at = updated_at
      @persist_calls = 0
    end

    def enabled?
      !!enabled
    end

    def persist_changes
      @persist_calls += 1
      self
    end
  end

  class FakeRecordable
    def self.recording_studio_embeddable_options
      { enabled: true, renderer: "recording_studio_embeddable/embeds/default" }
    end

    def self.model_name = ActiveModel::Name.new(self, nil, "FakePage")
  end

  FakeRecording = Struct.new(:recordable, :updated_at, :embed, :embeddable, keyword_init: true) do
    def embeddable?
      embeddable.nil? || embeddable
    end

    def ensure_embed!(actor: nil, **)
      @ensure_embed_actors ||= []
      @ensure_embed_actors << actor
      self.embed ||= MutableEmbed.new
    end

    def ensure_embed_actors
      @ensure_embed_actors || []
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
    assert_equal :view, descriptor[:required_role]
    assert_equal "RecordingStudioEmbeddable::Api::EmbedRecording", descriptor[:handler]
  end

  def test_enable_embed_descriptor_matches_admin_member_action
    descriptor = RecordingStudioEmbeddable::Api.enable_embed_descriptor

    assert_equal :enable_embed, descriptor[:name]
    assert_equal :embeddable, descriptor[:capability]
    assert_equal :post, descriptor[:http_verb]
    assert_equal :member, descriptor[:scope]
    assert_equal :admin, descriptor[:required_role]
    assert_equal "RecordingStudioEmbeddable::Api::EnableEmbedRecording", descriptor[:handler]
  end

  def test_disable_embed_descriptor_matches_admin_member_action
    descriptor = RecordingStudioEmbeddable::Api.disable_embed_descriptor

    assert_equal :disable_embed, descriptor[:name]
    assert_equal :embeddable, descriptor[:capability]
    assert_equal :post, descriptor[:http_verb]
    assert_equal :member, descriptor[:scope]
    assert_equal :admin, descriptor[:required_role]
    assert_equal "RecordingStudioEmbeddable::Api::DisableEmbedRecording", descriptor[:handler]
  end

  def test_registration_is_a_noop_without_recording_studio_api
    refute Object.const_defined?(:RecordingStudioApi, false)

    assert_nil RecordingStudioEmbeddable::Api.register_capability_action!
  end

  def test_registration_registers_embeddable_owned_member_action
    with_fake_recording_studio_api do |api|
      RecordingStudioEmbeddable::Api.register_capability_action!

      registration = registration_named(api, :embed)

      assert_equal :embed, registration.fetch(:name)
      assert_equal :embeddable, registration.fetch(:capability)
      assert_equal :get, registration.fetch(:http_verb)
      assert_equal :member, registration.fetch(:scope)
      assert_equal :view, registration.fetch(:required_role)
      assert_equal RecordingStudioEmbeddable::Api::EmbedRecording, registration.fetch(:handler)
      assert_equal RecordingStudioEmbeddable::Api::ACTION_SUMMARY, registration.fetch(:openapi).fetch(:summary)
      assert_equal RecordingStudioEmbeddable::Api::ACTION_RESPONSE_DESCRIPTIONS.fetch("403"),
                   registration.fetch(:openapi).fetch(:responses).fetch("403").fetch(:description)
    end
  end

  def test_registration_registers_enable_embed_on_legacy_api
    with_fake_recording_studio_api do |api|
      RecordingStudioEmbeddable::Api.register_capability_action!

      registration = registration_named(api, :enable_embed)

      assert_equal :enable_embed, registration.fetch(:name)
      assert_equal :embeddable, registration.fetch(:capability)
      assert_equal :post, registration.fetch(:http_verb)
      assert_equal :member, registration.fetch(:scope)
      assert_equal :admin, registration.fetch(:required_role)
      assert_equal RecordingStudioEmbeddable::Api::EnableEmbedRecording, registration.fetch(:handler)
      assert_equal RecordingStudioEmbeddable::Api::ENABLE_EMBED_ACTION_SUMMARY,
                   registration.fetch(:openapi).fetch(:summary)
    end
  end

  def test_registration_registers_disable_embed_on_legacy_api
    with_fake_recording_studio_api do |api|
      RecordingStudioEmbeddable::Api.register_capability_action!

      registration = registration_named(api, :disable_embed)

      assert_equal :disable_embed, registration.fetch(:name)
      assert_equal :embeddable, registration.fetch(:capability)
      assert_equal :post, registration.fetch(:http_verb)
      assert_equal :member, registration.fetch(:scope)
      assert_equal :admin, registration.fetch(:required_role)
      assert_equal RecordingStudioEmbeddable::Api::DisableEmbedRecording, registration.fetch(:handler)
      assert_equal RecordingStudioEmbeddable::Api::DISABLE_EMBED_ACTION_SUMMARY,
                   registration.fetch(:openapi).fetch(:summary)
    end
  end

  def test_registration_does_not_replace_an_existing_embed_action
    with_fake_recording_studio_api(existing_actions: { embed: Object.new }) do |api|
      RecordingStudioEmbeddable::Api.register_capability_action!

      refute(api.registrations.any? { |registration| registration[:name] == :embed })
      assert registration_named(api, :enable_embed)
      assert registration_named(api, :disable_embed)
    end
  end

  def test_enable_embed_registers_on_public_named_api_only
    with_named_recording_studio_apis do |api|
      RecordingStudioEmbeddable::Api.register_capability_action!

      embed_apis = registration_apis(api, :embed)
      enable_apis = registration_apis(api, :enable_embed)
      disable_apis = registration_apis(api, :disable_embed)

      assert_equal %i[public operations], embed_apis
      assert_equal %i[public], enable_apis
      assert_equal %i[public], disable_apis
      refute api.registries.dig(:operations, :enable_embed)
      refute api.registries.dig(:operations, :disable_embed)
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
    RecordingStudioEmbeddable::Api.override_openapi(
      type: "Page",
      action: :enable_embed,
      title: "Enable embed page"
    )
    enabled = RecordingStudioEmbeddable::Api.openapi_for(type: "Page", action: :enable_embed)

    assert_equal "Enable embed page", enabled.fetch(:title)
    assert_equal RecordingStudioEmbeddable::Api::ENABLE_EMBED_ACTION_DESCRIPTION, enabled.fetch(:description)

    RecordingStudioEmbeddable::Api.override_openapi(
      type: "Page",
      action: :disable_embed,
      title: "Disable embed page"
    )
    disabled = RecordingStudioEmbeddable::Api.openapi_for(type: "Page", action: :disable_embed)

    assert_equal "Disable embed page", disabled.fetch(:title)
    assert_equal RecordingStudioEmbeddable::Api::DISABLE_EMBED_ACTION_DESCRIPTION, disabled.fetch(:description)

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

      registration = registration_named(api, :embed)
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
      assert_equal [[recording, :view]], access_grant.authorized_recordings
      refute called
    end
  ensure
    RecordingStudioEmbeddable::Services::CaptureView.define_singleton_method(:call, original) if original
  end

  def test_handler_rejects_missing_embed_without_creating_one
    recording = FakeRecording.new(
      recordable: FakeRecordable.new,
      updated_at: Time.at(1_700_000_000),
      embed: nil
    )
    created = false
    recording.define_singleton_method(:ensure_embed!) do |**|
      created = true
      FakeEmbed.new
    end

    with_fake_recording_studio_api do
      error = assert_raises(RecordingStudioApi::NotFoundError) do
        RecordingStudioEmbeddable::Api::EmbedRecording.call(
          ActionContext.new(recording: recording, access_grant: AccessGrant.new, params: {})
        )
      end

      assert_match(/isn't set up for this recording yet/i, error.message)
      assert_match(/enable_embed/i, error.message)
      assert_match(/open the Embed screen once/i, error.message)
      refute_match(/press center/i, error.message)
      refute created
    end
  end

  def test_enable_embed_handler_authorizes_admin_and_returns_payload
    actor = Object.new
    access_grant = AccessGrant.new(actor: actor)
    embed = MutableEmbed.new(enabled: false)
    recording = FakeRecording.new(
      recordable: FakeRecordable.new,
      updated_at: Time.at(1_700_000_000),
      embed: embed
    )

    with_fake_recording_studio_api do
      hash = RecordingStudioEmbeddable::Api::EnableEmbedRecording.call(
        ActionContext.new(recording: recording, access_grant: access_grant, params: {})
      )

      assert_equal true, embed.enabled
      assert_equal 1, embed.persist_calls
      assert_equal [actor], recording.ensure_embed_actors
      assert_equal [[recording, :admin]], access_grant.authorized_recordings
      assert_equal 1, hash.fetch("schema_version")
      assert_equal "<p>payload</p>", hash.fetch("html")
    end
  end

  def test_enable_embed_handler_is_idempotent_when_already_enabled
    embed = MutableEmbed.new(enabled: true)
    recording = FakeRecording.new(
      recordable: FakeRecordable.new,
      updated_at: Time.at(1_700_000_000),
      embed: embed
    )

    with_fake_recording_studio_api do
      RecordingStudioEmbeddable::Api::EnableEmbedRecording.call(
        ActionContext.new(recording: recording, access_grant: AccessGrant.new, params: {})
      )
      RecordingStudioEmbeddable::Api::EnableEmbedRecording.call(
        ActionContext.new(recording: recording, access_grant: AccessGrant.new, params: {})
      )
    end

    assert_equal true, embed.enabled
    assert_equal 0, embed.persist_calls
    assert_equal 2, recording.ensure_embed_actors.size
  end

  def test_disable_embed_handler_authorizes_admin_and_returns_payload
    actor = Object.new
    access_grant = AccessGrant.new(actor: actor)
    embed = MutableEmbed.new(enabled: true)
    recording = FakeRecording.new(
      recordable: FakeRecordable.new,
      updated_at: Time.at(1_700_000_000),
      embed: embed
    )
    created = false
    recording.define_singleton_method(:ensure_embed!) do |**|
      created = true
      embed
    end

    with_fake_recording_studio_api do
      hash = RecordingStudioEmbeddable::Api::DisableEmbedRecording.call(
        ActionContext.new(recording: recording, access_grant: access_grant, params: {})
      )

      assert_equal false, embed.enabled
      assert_equal 1, embed.persist_calls
      refute created
      assert_equal [[recording, :admin]], access_grant.authorized_recordings
      assert_equal 1, hash.fetch("schema_version")
      assert_equal "<p>payload</p>", hash.fetch("html")
    end
  end

  def test_disable_embed_handler_is_idempotent_when_already_disabled
    embed = MutableEmbed.new(enabled: false)
    recording = FakeRecording.new(
      recordable: FakeRecordable.new,
      updated_at: Time.at(1_700_000_000),
      embed: embed
    )

    with_fake_recording_studio_api do
      RecordingStudioEmbeddable::Api::DisableEmbedRecording.call(
        ActionContext.new(recording: recording, access_grant: AccessGrant.new, params: {})
      )
      RecordingStudioEmbeddable::Api::DisableEmbedRecording.call(
        ActionContext.new(recording: recording, access_grant: AccessGrant.new, params: {})
      )
    end

    assert_equal false, embed.enabled
    assert_equal 0, embed.persist_calls
  end

  def test_disable_embed_handler_rejects_missing_embed_without_creating_one
    recording = FakeRecording.new(
      recordable: FakeRecordable.new,
      updated_at: Time.at(1_700_000_000),
      embed: nil
    )
    created = false
    recording.define_singleton_method(:ensure_embed!) do |**|
      created = true
      MutableEmbed.new
    end

    with_fake_recording_studio_api do
      error = assert_raises(RecordingStudioApi::NotFoundError) do
        RecordingStudioEmbeddable::Api::DisableEmbedRecording.call(
          ActionContext.new(recording: recording, access_grant: AccessGrant.new, params: {})
        )
      end

      assert_match(/isn't set up for this recording yet/i, error.message)
      assert_match(/no embed to turn off/i, error.message)
      refute created
    end
  end

  def test_enable_embed_handler_rejects_a_recording_that_is_not_embeddable
    created = false
    recording = FakeRecording.new(
      recordable: FakeRecordable.new,
      updated_at: Time.at(1_700_000_000),
      embed: nil,
      embeddable: false
    )
    recording.define_singleton_method(:ensure_embed!) do |**|
      created = true
      raise "should not create"
    end

    with_fake_recording_studio_api do
      error = assert_raises(RecordingStudioApi::NotFoundError) do
        RecordingStudioEmbeddable::Api::EnableEmbedRecording.call(
          ActionContext.new(recording: recording, access_grant: AccessGrant.new, params: {})
        )
      end

      assert_match(/not embeddable/i, error.message)
      refute created
    end
  end

  private

  def registration_named(api, name)
    api.registrations.find { |registration| registration[:name] == name }
  end

  def registration_apis(api, name)
    api.registrations.select { |registration| registration[:name] == name }.map { |r| r[:api] }
  end

  def with_fake_recording_studio_api(existing_actions: {})
    api = Module.new
    api.instance_variable_set(:@existing_actions, existing_actions)
    api.instance_variable_set(:@registrations, [])
    api.define_singleton_method(:capability_action) { |name| @existing_actions[name] }
    api.define_singleton_method(:register_capability_action) do |name, **options|
      @registrations << options.merge(name:)
    end
    api.define_singleton_method(:registrations) { @registrations }
    install_api_errors(api)

    Object.const_set(:RecordingStudioApi, api)
    yield api
  ensure
    Object.send(:remove_const, :RecordingStudioApi) if Object.const_defined?(:RecordingStudioApi, false)
  end

  def with_named_recording_studio_apis(names: %i[public operations])
    api = Module.new
    registries = names.to_h { |name| [name, {}] }
    registrations = []
    config = Object.new
    config.define_singleton_method(:each_api) do |&block|
      names.each do |name|
        definition = Object.new
        definition.define_singleton_method(:name) { name }
        block.call(definition)
      end
    end
    api.define_singleton_method(:configuration) { config }
    api.define_singleton_method(:capability_action) do |name, api: :public|
      registries.dig(api, name)
    end
    api.define_singleton_method(:register_capability_action) do |name, api: :public, **options|
      registrations << options.merge(name:, api:)
      registries[api] ||= {}
      registries[api][name] = options.merge(name:)
    end
    api.define_singleton_method(:registrations) { registrations }
    api.define_singleton_method(:registries) { registries }
    install_api_errors(api)

    Object.const_set(:RecordingStudioApi, api)
    yield api
  ensure
    Object.send(:remove_const, :RecordingStudioApi) if Object.const_defined?(:RecordingStudioApi, false)
  end

  def install_api_errors(api)
    api.const_set(:NotFoundError, Class.new(StandardError))
    api.const_set(:InvalidActionInputError, Class.new(StandardError) do
      attr_reader :details

      def initialize(message, details: [])
        super(message)
        @details = details
      end
    end)
  end
end
