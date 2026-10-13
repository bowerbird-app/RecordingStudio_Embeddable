# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class EmbeddableHostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_STYLING_DISABLED = "HOST Custom styling is disabled for this embed."
  HOST_EMBED_CODE_HELP = "HOST Paste this into your page."
  STYLING_DISABLED_KEY = "recording_studio.embeddable.flashes.styling_disabled"
  EMBED_CODE_HELP_KEY = "recording_studio.embeddable.management.edit.embed_code_help"
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_embeddable_host.en.yml")
  FRESH_HOST_LOCALE = Rails.root.join("test/locales/embeddable_host_override.en.yml")

  setup do
    @load_path_before = I18n.load_path.dup
    @backend_before = I18n.backend
    @previous_allow_custom_styling = RecordingStudioEmbeddable.configuration.allow_custom_styling
    @previous_require_publishable = RecordingStudioEmbeddable.configuration.require_publishable

    RecordingStudioEmbeddable.configuration.require_publishable = false

    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    sign_in @user

    Rails.application.load_seed
    page = Page.find_by!(title: "Getting Started")
    @page_recording = RecordingStudio::Recording.unscoped.find_by!(recordable: page)
    @embed = @page_recording.ensure_embed!(enabled: true, allowed_embedder_domains: ["example.com"])
  end

  teardown do
    RecordingStudioEmbeddable.configuration.allow_custom_styling = @previous_allow_custom_styling
    RecordingStudioEmbeddable.configuration.require_publishable = @previous_require_publishable
    I18n.backend = @backend_before if @backend_before
    assert_equal @load_path_before, I18n.load_path,
                 "test must not leave I18n.load_path modified"
  end

  # Real-boot-order guard: host file under config/locales must win without any
  # test-time load_path mutation. Render assertion uses the styling-disabled flash.
  test "host locale override for recording_studio.embeddable wins on boot order" do
    assert File.exist?(BOOT_HOST_LOCALE)
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_STYLING_DISABLED
    assert_equal HOST_STYLING_DISABLED, I18n.t(STYLING_DISABLED_KEY)
    assert_equal @load_path_before, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    RecordingStudioEmbeddable.configuration.allow_custom_styling = false

    patch recording_studio_embeddable.styling_management_embed_path(@embed),
          params: { embed: { appearance: { background_color: "#ffffff" } } }

    assert_response :redirect
    assert_equal HOST_STYLING_DISABLED, flash[:alert]
  end

  # Test-only fixture applied via backend.load_translations(file) on top of the
  # already-initialized backend — never mutates I18n.load_path.
  test "fresh-backend last-file-wins host fixture overrides gem english on edit page" do
    assert File.exist?(FRESH_HOST_LOCALE), "expected test-only host override fixture at #{FRESH_HOST_LOCALE}"
    assert_includes File.read(FRESH_HOST_LOCALE), HOST_EMBED_CODE_HELP

    snapshot = i18n_backend_translations_snapshot
    I18n.t(EMBED_CODE_HELP_KEY)
    I18n.backend.load_translations(FRESH_HOST_LOCALE.to_s)

    assert_equal @load_path_before, I18n.load_path
    assert_equal HOST_EMBED_CODE_HELP, I18n.t(EMBED_CODE_HELP_KEY)
    assert_equal HOST_STYLING_DISABLED, I18n.t(STYLING_DISABLED_KEY)

    get recording_studio_embeddable.edit_management_embed_path(@embed)
    assert_response :success
    assert_includes response.body, HOST_EMBED_CODE_HELP
    refute_includes response.body, "HOST Custom styling"
  ensure
    restore_i18n_backend_translations(snapshot) if snapshot
  end

  private

  def i18n_backend_translations_snapshot
    backend = I18n.backend
    backend.send(:init_translations) unless backend.initialized?
    translations =
      if backend.respond_to?(:translations)
        backend.translations
      else
        backend.instance_variable_get(:@translations)
      end
    return unless translations

    deep_plain_copy(translations)
  end

  def restore_i18n_backend_translations(snapshot)
    backend = I18n.backend
    backend.instance_variable_set(:@translations, snapshot)
    backend.instance_variable_set(:@initialized, true) if backend.instance_variable_defined?(:@initialized)
  end

  def deep_plain_copy(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, nested), copy| copy[key] = deep_plain_copy(nested) }
    when Array
      value.map { |nested| deep_plain_copy(nested) }
    else
      value
    end
  end
end
