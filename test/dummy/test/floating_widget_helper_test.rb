# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class FloatingWidgetHelperTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    sign_in @user
    Current.actor = @user

    workspace = Workspace.create!(name: "Helper #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    @widget = root.record(Widget, actor: @user) { |widget| widget.title = "Hello widget" }
    @embed = @widget.ensure_embed!(
      enabled: false,
      floating_enabled: true,
      floating: { "position" => "bottom-right" }
    )
    @page = root.record(Page, actor: @user) { |record| record.title = "Plain page" }
    @page_embed = @page.ensure_embed!(enabled: true)
  end

  teardown { Current.actor = nil }

  test "widget.js is a stable classic script" do
    get "/recording_studio_embeddable/widget.js"

    assert_response :success
    assert_includes response.media_type, "javascript"
    assert_includes response.body, "currentScript"
    assert_includes response.body, "data-embed"
    refute_includes response.body, "postMessage(payload, \"*\")"
  end

  test "local helper inlines launcher json and skips pages" do
    get widget_on_site_path(tokens: @embed.token)

    assert_response :success
    assert_includes response.body, "data-embed=\"#{@embed.token}\""
    assert_includes response.body, "data-config="
    assert_includes response.body, "http://www.example.com/widgets/#{@embed.token}"
    refute_includes response.body, @embed.id
    refute_includes @embed.reload.floating.to_json, "popup_url"

    get widget_on_site_path(tokens: @page_embed.token)
    assert_response :success
    refute_includes response.body, "data-config="
    refute_includes response.body, "widget.js"
  end

  test "install snippet fetches config and the launcher screen can copy it" do
    get widget_installed_path(token: @embed.token)

    assert_response :success
    assert_includes response.body, "widget.js"
    assert_includes response.body, "data-embed=\"#{@embed.token}\""
    refute_includes response.body, "data-config="

    get recording_studio_embeddable.edit_management_embed_path(@embed)
    assert_response :success
    refute_includes response.body, "launcher_snippet"
    refute_includes response.body, "Chat button snippet"
    assert_includes response.body, ">Chat button<"

    get recording_studio_embeddable.floating_management_embed_path(@embed)
    assert_response :success
    assert_includes response.body, "launcher_snippet"
    assert_includes response.body, "Chat button snippet"
    assert_includes response.body, @embed.token
    assert_includes response.body, "widget.js"
    assert_includes response.body, "copyFromButton"

    publish = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: @page,
      actor: @user,
      attributes: { slug: "plain-#{SecureRandom.hex(3)}", status: "published" }
    )
    raise publish.error unless publish.success?

    get recording_studio_embeddable.edit_management_embed_path(@page_embed)
    assert_response :success
    refute_includes response.body, "launcher_snippet"
  end
end
