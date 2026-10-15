# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class EmbeddableI18nRenderTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @previous_require_publishable = RecordingStudioEmbeddable.configuration.require_publishable
    @previous_public_embeds = RecordingStudioEmbeddable.configuration.public_embeds_enabled
    @previous_allow_any = RecordingStudioEmbeddable.configuration.allow_any_domain
    @previous_rate_limiting = RecordingStudioEmbeddable.configuration.rate_limiting_enabled

    RecordingStudioEmbeddable.configuration.require_publishable = false
    RecordingStudioEmbeddable.configuration.public_embeds_enabled = true
    RecordingStudioEmbeddable.configuration.allow_any_domain = true
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = false

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
    RecordingStudioEmbeddable.configuration.require_publishable = @previous_require_publishable
    RecordingStudioEmbeddable.configuration.public_embeds_enabled = @previous_public_embeds
    RecordingStudioEmbeddable.configuration.allow_any_domain = @previous_allow_any
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = @previous_rate_limiting
    I18n.locale = I18n.default_locale
  end

  test "management edit renders gem english copy" do
    get recording_studio_embeddable.edit_management_embed_path(@embed)

    assert_response :success
    assert_includes response.body, "Embed"
    assert_includes response.body, "Add this code to your website wherever you want this to appear, for example inside a page or blog post."
    assert_includes response.body, "Paste it into the page&#39;s HTML, or ask your web developer to add it."
    assert_includes response.body, "Using Squarespace, Wix or WordPress?"
    assert_includes response.body, "Custom code"
    refute_includes response.body, "Paste this into your page."
    assert_includes response.body, "Preview"
    assert_includes response.body, "Embed style"
    assert_includes response.body, "Settings"
    assert_includes response.body, "Stats"
    refute_includes response.body, "translation missing"
  end

  test "management settings styling and stats render gem english copy" do
    get recording_studio_embeddable.settings_management_embed_path(@embed)
    assert_response :success
    assert_includes response.body, "Embed settings"
    assert_includes response.body, "Allowed domains (one per line)"
    assert_includes response.body, "Save changes"

    get recording_studio_embeddable.styling_management_embed_path(@embed)
    assert_response :success
    assert_includes response.body, "Embed style"
    assert_includes response.body, "Save"
    assert_includes response.body, "Reset"
    assert_includes response.body, "Width"
    assert_includes response.body, "Auto"
    assert_includes response.body, "Custom"

    get recording_studio_embeddable.stats_management_embed_path(@embed)
    assert_response :success
    assert_includes response.body, "Stats"
    assert_includes response.body, "Last 30 days"
    assert_includes response.body, "All views"
    assert_includes response.body, "Per day"
    assert_includes response.body, "Countries"
    assert_includes response.body, "No geo access data for this filter and date range."
  end

  test "stats filters keep raw tokens under a translated locale" do
    previous_available = I18n.available_locales
    I18n.available_locales = previous_available | [:fr]
    I18n.backend.store_translations(
      :fr,
      recording_studio: {
        embeddable: {
          management: {
            stats: {
              viewers: {
                humans: "Humains seulement"
              },
              ranges: {
                thirty_days: "30 derniers jours"
              },
              granularities: {
                day: "Par jour"
              }
            }
          }
        }
      }
    )

    I18n.with_locale(:fr) do
      get recording_studio_embeddable.stats_management_embed_path(
        @embed,
        range: "30d",
        viewer: "humans",
        granularity: "day"
      )

      assert_response :success
      assert_includes response.body, "Humains seulement"
      assert_includes response.body, "30 derniers jours"
      assert_includes response.body, "Par jour"
      assert_match(%r{viewer=humans}, response.body)
      assert_match(%r{range=30d}, response.body)
      assert_match(%r{granularity=day}, response.body)
    end
  ensure
    I18n.available_locales = previous_available if previous_available
  end

  test "public not found renders gem english empty state" do
    get "/recording_studio_embeddable/embeds/missing-token-i18n-check"

    assert_response :not_found
    assert_includes response.body, "Oops"
    assert_includes response.body, "This embed is gone, or the link is wrong. Check the address and try again."
  end

  test "settings updated flash key stays gem english" do
    assert_equal(
      "Embed settings updated.",
      I18n.t("recording_studio.embeddable.flashes.settings_updated", default: "Embed settings updated.")
    )
  end
end
