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
      per_ip_rate_limit: RecordingStudioEmbeddable.configuration.per_ip_rate_limit,
      invalid_token_rate_limit: RecordingStudioEmbeddable.configuration.invalid_token_rate_limit,
      invalid_token_rate_limit_window: RecordingStudioEmbeddable.configuration.invalid_token_rate_limit_window,
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
    root = RecordingStudio.create_root_recording!(workspace, actor: @user)
    grant_embed_management!(actor: @user, recording: root)
    @widget_recording = root.record(Widget, actor: @user) { |widget| widget.title = "Hello widget" }
    @widget_embed = @widget_recording.ensure_embed!(
      enabled: true,
      floating_enabled: true,
      allowed_embedder_domains: ["partner.example.com"],
      floating: { "position" => "bottom-left" }
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
    vary = response.headers["Vary"].to_s.split(",").map(&:strip)
    assert_includes vary, "Origin"
    assert_includes vary, "Accept"
    assert_includes vary, "X-Requested-With"
    assert_nil response.headers["Access-Control-Allow-Credentials"]
    refute_includes response.headers["Access-Control-Allow-Origin"].to_s, "*"

    body = JSON.parse(response.body)
    assert_equal @widget_embed.token, body.fetch("id")
    refute_includes response.body, @widget_embed.id
    assert_equal "bottom-left", body.fetch("position")
    assert_equal 24, body.fetch("edge_spacing")
    assert_equal 400, body.fetch("popup_width")
    assert_equal 640, body.fetch("popup_height")
    assert_nil body.fetch("icon_url")
    refute @widget_embed.reload.floating.key?("edge_spacing")
    assert_equal "#111827", body.dig("colors", "background")
    assert_equal "http://www.example.com/widgets/#{@widget_embed.token}", body.fetch("popup_url")
    refute body.key?("sandbox")
    refute body.key?("allow")
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

    @widget_recording.update_embed!(actor: @user, enabled: false)
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

  test "launcher json renders sandbox and allow from floating_defaults" do
    previous = RecordingStudioEmbeddable.configuration.floating_defaults
    RecordingStudioEmbeddable.configuration.floating_defaults = previous.merge(
      "sandbox" => %w[allow-scripts allow-same-origin allow-forms allow-popups],
      "allow" => "clipboard-write"
    )

    get "/recording_studio_embeddable/embeds/#{@widget_embed.token}/launcher",
        headers: { "Origin" => "https://partner.example.com" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "allow-scripts allow-same-origin allow-forms allow-popups", body.fetch("sandbox")
    assert_equal "clipboard-write", body.fetch("allow")
    assert_equal 24, body.fetch("edge_spacing")
    refute_includes @widget_embed.reload.floating.to_json, "sandbox"
    refute_includes @widget_embed.floating.to_json, "clipboard-write"
  ensure
    RecordingStudioEmbeddable.configuration.floating_defaults = previous if previous
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

  test "launcher hides embeds that are not public" do
    title = "Hello widget"
    path = "/recording_studio_embeddable/embeds/#{@widget_embed.token}/launcher"
    headers = { "Origin" => "https://partner.example.com" }

    with_widget_publish_required do
      assert_hidden_launcher(path, headers, title)

      publish_widget!
      get path, headers: headers
      assert_response :success
      assert_equal title, JSON.parse(response.body).fetch("title")
    end

    RecordingStudioEmbeddable.configuration.public_embeds_enabled = false
    assert_hidden_launcher(path, headers, title)
    RecordingStudioEmbeddable.configuration.public_embeds_enabled = true

    @widget_recording.update_embed!(actor: @user, enabled: false, floating_enabled: true)
    assert_hidden_launcher(path, headers, title)
    options path, headers: headers.merge("Access-Control-Request-Method" => "GET")
    assert_response :not_found
    assert_empty response.body

    @widget_recording.disable_embed!(actor: @user)
    @widget_embed.reload
    assert_equal false, @widget_embed.enabled
    assert_equal false, @widget_embed.floating_enabled
    assert_hidden_launcher(path, headers, title)

    @widget_recording.update_embed!(actor: @user, enabled: true, floating_enabled: true)
    @widget_recording.update_columns(trashed_at: Time.current)
    assert_hidden_launcher(path, headers, title)
  end

  test "launcher rate limit runs before the embed lookup" do
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = true
    RecordingStudioEmbeddable.configuration.rate_limiter = :rails_cache
    RecordingStudioEmbeddable.configuration.rate_limit = 1

    headers = { "Origin" => "https://partner.example.com" }
    path = "/recording_studio_embeddable/embeds/missing-token-#{SecureRandom.hex(4)}/launcher"
    get path, headers: headers
    assert_response :not_found
    assert_empty response.body

    get path, headers: headers
    assert_response :too_many_requests
    assert_empty response.body
  end

  test "random tokens on the launcher hit the miss budget" do
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    configuration = RecordingStudioEmbeddable.configuration
    configuration.rate_limiting_enabled = true
    configuration.rate_limiter = :rails_cache
    configuration.rate_limit = 100
    configuration.per_ip_rate_limit = 100
    configuration.invalid_token_rate_limit = 3
    configuration.invalid_token_rate_limit_window = 45

    headers = { "Origin" => "https://partner.example.com" }
    3.times do |index|
      get "/recording_studio_embeddable/embeds/missing-#{index}-#{SecureRandom.hex(4)}/launcher",
          headers: headers,
          env: { "REMOTE_ADDR" => "203.0.113.40" }
      assert_response :not_found
      assert_empty response.body
    end

    queries = embed_queries do
      get "/recording_studio_embeddable/embeds/missing-over-#{SecureRandom.hex(4)}/launcher",
          headers: headers,
          env: { "REMOTE_ADDR" => "203.0.113.40" }
    end

    assert_response :too_many_requests
    assert_equal "45", response.headers["Retry-After"]
    assert_empty response.body
    assert_empty queries
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

  private

  def embed_queries
    queries = []
    callback = lambda do |_name, _started, _finished, _id, payload|
      sql = payload[:sql].to_s
      queries << sql if sql.match?(/recording_studio_embeddable_embeds/i)
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end

  def assert_hidden_launcher(path, headers, title)
    get path, headers: headers
    assert_response :not_found
    assert_empty response.body
    refute_includes response.body, title
  end

  def with_widget_publish_required
    options = widget_embeddable_options
    previous = options[:require_publishable]
    options[:require_publishable] = true
    yield
  ensure
    options[:require_publishable] = previous if options
  end

  def widget_embeddable_options
    Widget.recording_studio_capabilities
          .find { |candidate| candidate.respond_to?(:key) && candidate.key.to_sym == :embeddable }
          .options
  end

  def publish_widget!
    result = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: @widget_recording,
      actor: @user,
      attributes: { slug: "hello-widget-#{SecureRandom.hex(3)}", status: "published" }
    )
    raise result.error unless result.success?
  end
end
