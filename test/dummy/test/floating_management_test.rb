# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class FloatingManagementTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @previous_hosts = RecordingStudioEmbeddable.configuration.floating_icon_hosts
    RecordingStudioEmbeddable.configuration.floating_icon_hosts = ["images.example.com"]
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    sign_in @user
    Current.actor = @user

    workspace = Workspace.create!(name: "Manage #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    @widget = root.record(Widget, actor: @user) { |widget| widget.title = "Hello widget" }
    @embed = @widget.ensure_embed!(floating_enabled: false, floating: { "position" => "bottom-right" })
    @page = root.record(Page, actor: @user) { |record| record.title = "Inline page" }
    @page_embed = @page.ensure_embed!(enabled: true)
  end

  teardown do
    RecordingStudioEmbeddable.configuration.floating_icon_hosts = @previous_hosts
    Current.actor = nil
  end

  test "launcher screen is only for capable types and saves settings" do
    get recording_studio_embeddable.floating_management_embed_path(@page_embed)
    assert_response :not_found

    get recording_studio_embeddable.edit_management_embed_path(@page_embed)
    assert_response :success
    refute_includes response.body, ">Launcher<"

    get recording_studio_embeddable.floating_management_embed_path(@embed)
    assert_response :success
    refute_includes response.body, "launcher_snippet"
    assert_includes response.body, "Show the button"
    refute_includes response.body, "Edge spacing"
    refute_includes response.body, "Panel width"
    refute_includes response.body, "Panel height"
    refute_includes response.body, "Icon link"
    assert_includes response.body, "Position"
    refute_includes response.body, ">Corner<"
    assert_select "form#launcher-settings.space-y-6"
    assert_select "input[type=radio][name=?][value=?][checked]", "embed[floating][position]", "bottom-right"
    assert_select "input[type=radio][name=?][value=?]", "embed[floating][position]", "bottom-left"
    assert_select "select[name=?]", "embed[floating][position]", count: 0
    assert_includes response.body, "Visitors see this"
    assert_includes response.body, "data-config="
    assert_includes response.body, "data-preview-root="

    get recording_studio_embeddable.edit_management_embed_path(@embed)
    assert_response :success
    assert_includes response.body, ">Launcher<"
    refute_includes response.body, "launcher_snippet"

    patch recording_studio_embeddable.floating_management_embed_path(@embed),
          params: {
            embed: {
              floating_enabled: "1",
              floating: {
                position: "bottom-left",
                edge_spacing: "12",
                popup_width: "320",
                popup_height: "480",
                icon_url: "https://images.example.com/icon.png",
                popup_url: "https://evil.example/widget"
              }
            }
          }

    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_includes response.body, "launcher_snippet"
    assert_includes response.body, "Launcher snippet"
    assert_includes response.body, "widget.js"
    assert_includes response.body, "copyFromButton"
    @embed.reload
    assert_equal true, @embed.floating_enabled
    assert_equal "bottom-left", @embed.floating["position"]
    assert_equal ["position"], @embed.floating.keys
    refute_includes @embed.floating.to_json, "edge_spacing"
    refute_includes @embed.floating.to_json, "icon_url"
    refute_includes @embed.floating.to_json, "popup_url"
  end

  test "widget preview renders the widget" do
    get recording_studio_embeddable.preview_management_embed_path(@embed)

    assert_response :success
    assert_includes response.body, "Hello widget"
    refute_includes response.body, "Template is missing"
  end

  test "an unset position renders bottom right" do
    RecordingStudioEmbeddable::Embed.where(id: @embed.id).update_all(floating: {})

    get recording_studio_embeddable.floating_management_embed_path(@embed)

    assert_response :success
    assert_select "legend", text: "Position"
    assert_select "label", text: "Bottom left"
    assert_select "label", text: "Bottom right"
    assert_select "input[type=radio][name=?][value=?][checked]", "embed[floating][position]", "bottom-right"
    assert_select "input[type=radio][name=?][value=?][checked]", "embed[floating][position]", "bottom-left", count: 0
  end

  test "posted host settings are not stored on the embed" do
    patch recording_studio_embeddable.floating_management_embed_path(@embed),
          params: {
            embed: {
              floating_enabled: "1",
              floating: {
                position: "bottom-right",
                edge_spacing: "20",
                popup_width: "380",
                popup_height: "560",
                icon_url: "javascript:alert(1)"
              }
            }
          }

    assert_response :redirect
    @embed.reload
    assert_equal true, @embed.floating_enabled
    assert_equal({ "position" => "bottom-right" }, @embed.floating.to_h)
    refute_includes @embed.floating.to_json, "javascript"
  end
end
