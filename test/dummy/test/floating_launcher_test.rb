# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class FloatingLauncherTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @previous = {
      require_publishable: RecordingStudioEmbeddable.configuration.require_publishable,
      public_embeds_enabled: RecordingStudioEmbeddable.configuration.public_embeds_enabled,
      allow_any_domain: RecordingStudioEmbeddable.configuration.allow_any_domain,
      require_domain_allowlist: RecordingStudioEmbeddable.configuration.require_domain_allowlist,
      rate_limiting_enabled: RecordingStudioEmbeddable.configuration.rate_limiting_enabled,
      rate_limit: RecordingStudioEmbeddable.configuration.rate_limit,
      rate_limiter: RecordingStudioEmbeddable.configuration.rate_limiter,
      floating_icon_hosts: RecordingStudioEmbeddable.configuration.floating_icon_hosts
    }
    @previous_cache = Rails.cache

    RecordingStudioEmbeddable.configuration.require_publishable = false
    RecordingStudioEmbeddable.configuration.public_embeds_enabled = true
    RecordingStudioEmbeddable.configuration.allow_any_domain = false
    RecordingStudioEmbeddable.configuration.require_domain_allowlist = true
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = false
    RecordingStudioEmbeddable.configuration.floating_icon_hosts = ["images.example.com"]

    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    sign_in @user
    Current.actor = @user

    workspace = Workspace.create!(name: "Floating #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    @widget_recording = root.record(Widget, actor: @user) { |widget| widget.title = "Hello widget" }
    @widget_embed = @widget_recording.ensure_embed!(
      enabled: false,
      floating_enabled: true,
      allowed_embedder_domains: ["partner.example.com"],
      floating: {
        "position" => "bottom-left",
        "edge_spacing" => 16,
        "popup_width" => 320,
        "popup_height" => 480
      }
    )

    @page_recording = root.record(Page, actor: @user) { |record| record.title = "Inline only page" }
    @page_embed = @page_recording.ensure_embed!(enabled: false, allowed_embedder_domains: ["partner.example.com"])
  end

  teardown do
    @previous.each do |key, value|
      RecordingStudioEmbeddable.configuration.public_send("#{key}=", value)
    end
    Rails.cache = @previous_cache
    Current.actor = nil
  end

  test "launcher json uses the token and echoes an allowlisted origin" do
    get "/recording_studio_embeddable/embeds/#{@widget_embed.token}/launcher",
        headers: { "Origin" => "https://partner.example.com" }

    assert_response :success
    assert_equal "https://partner.example.com", response.headers["Access-Control-Allow-Origin"]
    assert_equal "Origin", response.headers["Vary"]
    assert_nil response.headers["Access-Control-Allow-Credentials"]
    refute_includes response.headers["Access-Control-Allow-Origin"].to_s, "*"

    body = JSON.parse(response.body)
    assert_equal @widget_embed.token, body.fetch("id")
    refute_includes response.body, @widget_embed.id
    assert_equal "bottom-left", body.fetch("position")
    assert_equal 16, body.fetch("edge_spacing")
    assert_equal "#111827", body.dig("colors", "background")
    assert_equal "http://www.example.com/widgets/#{@widget_embed.token}", body.fetch("popup_url")
    refute_includes @widget_embed.reload.floating.to_json, "popup_url"
    refute_includes @widget_embed.floating.to_json, "http"
  end

  test "launcher fails closed without an origin and hides disallowed origins" do
    get "/recording_studio_embeddable/embeds/#{@widget_embed.token}/launcher"
    assert_response :forbidden
    assert_nil response.headers["Access-Control-Allow-Origin"]

    get "/recording_studio_embeddable/embeds/#{@widget_embed.token}/launcher",
        headers: { "Origin" => "*" }
    assert_response :forbidden
    assert_nil response.headers["Access-Control-Allow-Origin"]

    get "/recording_studio_embeddable/embeds/#{@widget_embed.token}/launcher",
        headers: { "Origin" => "https://evil.example.com" }
    assert_response :forbidden
    assert_nil response.headers["Access-Control-Allow-Origin"]
  end

  test "page embeds never launch and public params cannot enable floating" do
    get "/recording_studio_embeddable/embeds/#{@page_embed.token}/launcher",
        headers: { "Origin" => "https://partner.example.com" }
    assert_response :not_found

    patch recording_studio_embeddable.management_embed_path(@page_embed),
          params: {
            embed: {
              enabled: "1",
              floating_enabled: "1",
              floating: { position: "bottom-left", popup_url: "https://evil.example/widget" }
            }
          }

    assert_response :redirect
    @page_embed.reload
    assert_equal true, @page_embed.enabled
    assert_equal false, @page_embed.floating_enabled
    assert_equal({}, @page_embed.read_attribute(:floating))

    assert_raises(ActiveRecord::RecordInvalid) do
      @page_embed.floating_enabled = true
      @page_embed.persist_changes!
    end
    assert_equal false, @page_embed.reload.floating_enabled

    @page_recording.update_embed!(floating_enabled: true, floating: { "position" => "bottom-left" })
    assert_equal false, @page_embed.reload.floating_enabled
    assert_equal({}, @page_embed.read_attribute(:floating))
  end

  test "widget update rejects invalid launcher settings and keeps inline embed off" do
    assert_raises(ActiveRecord::RecordInvalid) do
      @widget_embed.floating = { "position" => "top", "popup_url" => "https://evil.example" }
      @widget_embed.persist_changes!
    end
    assert_equal "bottom-left", @widget_embed.reload.floating["position"]

    get "/recording_studio_embeddable/embeds/#{@widget_embed.token}",
        headers: { "Origin" => "https://partner.example.com" }
    assert_response :not_found

    publish = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: @page_recording,
      actor: @user,
      attributes: { slug: "inline-only-#{SecureRandom.hex(3)}", status: "published" }
    )
    raise publish.error unless publish.success?
    @page_recording.update_embed!(enabled: true)

    get "/recording_studio_embeddable/embeds/#{@page_embed.token}?floating_enabled=true",
        headers: { "Origin" => "https://partner.example.com" }
    assert_response :success
    refute_includes response.body, "widget.js"
    refute_includes response.body, "data-recording-studio-widget"
    assert_equal false, @page_embed.reload.floating_enabled
  end

  test "render payload and cdn publisher stay free of launcher config" do
    result = RecordingStudioEmbeddable::RenderPayload.call(recording: @page_recording, embed: @page_embed)
    configuration = result.value!.to_h.fetch("configuration")

    assert_equal %w[sizing theme].sort, configuration.keys.sort
    refute configuration.key?("floating")
    refute configuration.key?("popup_url")
  end

  test "launcher is rate limited" do
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = true
    RecordingStudioEmbeddable.configuration.rate_limiter = :rails_cache
    RecordingStudioEmbeddable.configuration.rate_limit = 1

    headers = { "Origin" => "https://partner.example.com" }
    path = "/recording_studio_embeddable/embeds/#{@widget_embed.token}/launcher"
    get path, headers: headers
    assert_response :success

    get path, headers: headers
    assert_response :too_many_requests
    assert_equal "https://partner.example.com", response.headers["Access-Control-Allow-Origin"]
    refute_includes response.headers["Access-Control-Allow-Origin"].to_s, "*"
  end

  test "forced floating flag on a page still does not launch" do
    RecordingStudioEmbeddable::Embed.where(id: @page_embed.id).update_all(
      floating_enabled: true,
      floating: { "position" => "bottom-right" }
    )

    get "/recording_studio_embeddable/embeds/#{@page_embed.token}/launcher",
        headers: { "Origin" => "https://partner.example.com" }

    assert_response :not_found
  end
end
