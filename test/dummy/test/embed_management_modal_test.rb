# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class EmbedManagementModalTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    sign_in @user
    Current.actor = @user

    workspace = Workspace.create!(name: "Modal #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    @page = root.record(Page, actor: @user) { |record| record.title = "Modal page" }
    @page_embed = @page.ensure_embed!(enabled: true, allowed_embedder_domains: ["example.com"])
    @widget = root.record(Widget, actor: @user) { |widget| widget.title = "Modal chat" }
    @widget_embed = @widget.ensure_embed!(
      enabled: true,
      floating_enabled: true,
      floating: { "position" => "bottom-right" },
      allowed_embedder_domains: ["example.com"]
    )
  end

  teardown { Current.actor = nil }

  test "full page styling keeps the default layout" do
    get recording_studio_embeddable.styling_management_embed_path(@page_embed)

    assert_response :success
    assert_select "nav[aria-label='Page navigation']", count: 1
    assert_select "turbo-frame##{RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID}", count: 0
    assert_includes response.body, "Style"
    refute_includes response.body, "variant=modal"
    refute_includes response.body, ">Settings<"

    get recording_studio_embeddable.edit_management_embed_path(@page_embed)

    assert_response :success
    assert_select "nav[aria-label='Page navigation']", count: 1
    assert_select "turbo-frame##{RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID}", count: 0
    assert_select "a[data-turbo=false][href=?]",
      recording_studio_embeddable.preview_management_embed_path(@page_embed)
    refute_includes response.body, "variant=modal"
  end

  test "turbo frame request renders the modal variant" do
    get recording_studio_embeddable.styling_management_embed_path(@page_embed),
        headers: frame_headers

    assert_modal_frame
    assert_includes response.body, "Style"
    assert_includes response.body, "variant=modal"
    assert_includes response.body, ">Settings<"
    assert_select "a[data-turbo=false]", count: 0
    assert_match(/data-turbo-frame="#{RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID}"/, response.body)
  end

  test "variant and modal params render the modal variant without a frame header" do
    get recording_studio_embeddable.settings_management_embed_path(@widget_embed, variant: "modal")

    assert_modal_frame
    assert_includes response.body, "Embed settings"
    assert_includes response.body, "Allowed domains (one per line)"

    get recording_studio_embeddable.stats_management_embed_path(@widget_embed, modal: "1")

    assert_modal_frame
    assert_includes response.body, "Stats"
  end

  test "full page preview stays a document and modal preview stays in the frame" do
    get recording_studio_embeddable.preview_management_embed_path(@page_embed)

    assert_response :success
    assert_includes response.body, 'name="turbo-visit-control"'
    refute_includes response.body, RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID

    get recording_studio_embeddable.preview_management_embed_path(@page_embed),
        headers: frame_headers

    assert_modal_frame
    assert_includes response.body, "Preview"
    assert_select "iframe[src=?]", recording_studio_embeddable.preview_management_embed_path(@page_embed)
  end

  test "settings validation error and successful save stay in the frame" do
    patch recording_studio_embeddable.management_embed_path(@widget_embed),
          params: settings_params("localhost"),
          headers: frame_headers

    assert_response :unprocessable_entity
    assert_modal_frame
    assert_includes response.body, "Invalid embedder domain: localhost"
    assert_includes response.body, "Embed settings"

    patch recording_studio_embeddable.management_embed_path(@widget_embed),
          params: settings_params("partner.example"),
          headers: frame_headers

    assert_response :redirect
    assert_match(/variant=modal/, response.location)
    follow_redirect!

    assert_response :success
    assert_modal_frame
    assert_includes response.body, "Embed settings updated."
    @widget_embed.reload
    assert_includes @widget_embed.allowed_domains, "partner.example"
  end

  test "full page settings save still redirects into the default layout" do
    patch recording_studio_embeddable.management_embed_path(@widget_embed),
          params: {
            form_context: "settings",
            embed: { allowed_embedder_domains_text: "partner.example", enabled: "1" }
          }

    assert_response :redirect
    refute_match(/variant=modal/, response.location)
    follow_redirect!
    assert_response :success
    assert_select "nav[aria-label='Page navigation']", count: 1
    assert_includes response.body, "Embed settings updated."
  end

  test "floating screen renders in the modal frame" do
    get recording_studio_embeddable.floating_management_embed_path(@widget_embed),
        headers: frame_headers

    assert_modal_frame
    assert_includes response.body, "Chat button"
    assert_select "iframe#embed-floating-preview"
    assert_includes response.body, "copyFromButton"
    assert_includes response.body, "contentDocument"
    assert_includes response.body, "turbo:frame-load"
  end

  test "styling validation error stays in the frame" do
    patch recording_studio_embeddable.styling_management_embed_path(@page_embed),
          params: {
            variant: "modal",
            embed: { appearance: { text_color: "not-a-color" }, sizing: { width: "100%", height: "auto" } }
          },
          headers: frame_headers

    assert_response :unprocessable_entity
    assert_modal_frame
    assert_includes response.body, "Text color must be a valid hex color"
  end

  test "demo page renders one modal shell and an opener for page and widget" do
    Rails.application.load_seed
    get embed_modals_path

    assert_response :success
    assert_select "##{RecordingStudioEmbeddable::MANAGEMENT_MODAL_ID}", count: 1
    assert_select "turbo-frame##{RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID}", count: 1
    assert_select "[data-recording-studio-embeddable-management-src]", count: 2
    assert_select "button", text: "Page embed"
    assert_select "button", text: "Chat button"
    page_src = css_select("[data-recording-studio-embeddable-management-src]").first["data-recording-studio-embeddable-management-src"]
    widget_src = css_select("[data-recording-studio-embeddable-management-src]").last["data-recording-studio-embeddable-management-src"]
    assert_includes page_src, "/styling"
    assert_includes page_src, "variant=modal"
    assert_includes widget_src, "/floating"
    assert_includes widget_src, "variant=modal"
  end

  private

  def frame_headers
    { "Turbo-Frame" => RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID }
  end

  def settings_params(domains)
    {
      variant: "modal",
      form_context: "settings",
      embed: { allowed_embedder_domains_text: domains, enabled: "1" }
    }
  end

  def assert_modal_frame
    assert_response :success unless response.redirect? || response.unprocessable?
    assert_select "turbo-frame##{RecordingStudioEmbeddable::MANAGEMENT_FRAME_ID}", count: 1
    assert_select "nav[aria-label='Page navigation']", count: 0
    refute_match(/<html/i, response.body)
  end
end
