# frozen_string_literal: true

require "test_helper"

class WidgetPopupSecurityTest < ActionDispatch::IntegrationTest
  setup do
    @forgery = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous = {
      allow_any_domain: RecordingStudioEmbeddable.configuration.allow_any_domain,
      require_domain_allowlist: RecordingStudioEmbeddable.configuration.require_domain_allowlist,
      rate_limiting_enabled: RecordingStudioEmbeddable.configuration.rate_limiting_enabled
    }
    RecordingStudioEmbeddable.configuration.allow_any_domain = false
    RecordingStudioEmbeddable.configuration.require_domain_allowlist = true
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = false

    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    Current.actor = @user
    workspace = Workspace.create!(name: "Popup #{SecureRandom.hex(4)}")
    root = RecordingStudio.create_root_recording!(workspace, actor: @user)
    @widget = root.record(Widget, actor: @user) { |widget| widget.title = "Hello widget" }
    @embed = @widget.ensure_embed!(
      enabled: true,
      floating_enabled: true,
      allowed_embedder_domains: ["partner.example.com"]
    )
    @page = root.record(Page, actor: @user) { |record| record.title = "Not a widget" }
    @page_embed = @page.ensure_embed!(enabled: true, allowed_embedder_domains: ["partner.example.com"])
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery
    @previous.each { |key, value| RecordingStudioEmbeddable.configuration.public_send("#{key}=", value) }
    Current.actor = nil
  end

  test "popup sets a partitioned csrf cookie and rejects a forged post" do
    https!
    get widget_popup_path(@embed.token), headers: { "Referer" => "https://partner.example.com/page" }

    assert_response :success
    assert_includes response.body, "Name"
    assert_includes response.body, "Send"
    cookie = response.headers["Set-Cookie"].to_s
    assert_includes cookie, "recording_studio_embeddable_widget_csrf"
    assert_match(/samesite=none/i, cookie)
    assert_match(/secure/i, cookie)
    assert_match(/httponly/i, cookie)
    assert_match(/partitioned/i, cookie)
    refute_includes cookie, "_dummy_session"
    assert_includes response.headers["Content-Security-Policy"], "https://partner.example.com"
    assert_equal "private, no-store", response.headers["Cache-Control"]
    refute_includes response.body, "recording_studio_artifacts"
    assert_includes response.body, "widget_bridge.js"
    refute_includes response.body, 'content="*"'

    https!
    assert_no_difference("WidgetInquiry.count") do
      post widget_inquiries_path(@embed.token),
           params: { inquiry: { name: "Ada", email: "ada@example.com", message: "Hello" } },
           headers: { "Origin" => "https://www.example.com" }
    end
    assert_response :unprocessable_entity
  end

  test "a real authenticity token saves the note" do
    https!
    get widget_popup_path(@embed.token), headers: { "Referer" => "https://partner.example.com/page" }
    token = response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    assert token

    https!
    post widget_inquiries_path(@embed.token),
         params: {
           authenticity_token: token,
           inquiry: { name: "Ada", email: "ada@example.com", message: "Hello" }
         },
         headers: { "Origin" => "https://www.example.com" }

    assert_response :success
    assert_includes response.body, "Thanks, we got your note."
    assert_equal 1, WidgetInquiry.where(widget_token: @embed.token).count
    assert_equal true, @embed.reload.enabled
  end

  test "pages are not a popup and the bridge is not an embed document" do
    https!
    get widget_popup_path(@page_embed.token)
    assert_response :not_found

    get "/recording_studio_embeddable/widget_bridge.js"
    assert_response :success
    assert_includes response.body, "postMessage"
    refute_match(/postMessage\(\s*[^,\n]+,\s*["']\*["']\s*\)/, response.body)
  end

  test "popup hides embeds that are not public" do
    title = "Hello widget"
    path = widget_popup_path(@embed.token)
    headers = { "Referer" => "https://partner.example.com/page" }

    with_widget_publish_required do
      assert_hidden_popup(path, headers, title)

      publish_widget!
      https!
      get path, headers: headers
      assert_response :success
      assert_includes response.body, title
    end

    previous_public = RecordingStudioEmbeddable.configuration.public_embeds_enabled
    RecordingStudioEmbeddable.configuration.public_embeds_enabled = false
    assert_hidden_popup(path, headers, title)
    RecordingStudioEmbeddable.configuration.public_embeds_enabled = previous_public

    @widget.update_embed!(actor: @user, enabled: false, floating_enabled: true)
    assert_hidden_popup(path, headers, title)

    @widget.disable_embed!(actor: @user)
    @embed.reload
    assert_equal false, @embed.enabled
    assert_equal false, @embed.floating_enabled
    assert_hidden_popup(path, headers, title)

    @widget.update_embed!(actor: @user, enabled: true, floating_enabled: true)
    @widget.update_columns(trashed_at: Time.current)
    assert_hidden_popup(path, headers, title)
  end

  test "popup rate limit runs before the embed lookup" do
    previous_cache = Rails.cache
    previous_limit = RecordingStudioEmbeddable.configuration.rate_limit
    previous_limiter = RecordingStudioEmbeddable.configuration.rate_limiter
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = true
    RecordingStudioEmbeddable.configuration.rate_limiter = :rails_cache
    RecordingStudioEmbeddable.configuration.rate_limit = 1

    path = widget_popup_path("missing-#{SecureRandom.hex(4)}")
    https!
    get path
    assert_response :not_found
    assert_empty response.body

    https!
    get path
    assert_response :too_many_requests
    refute_includes response.body, "Hello widget"
  ensure
    Rails.cache = previous_cache if previous_cache
    RecordingStudioEmbeddable.configuration.rate_limit = previous_limit if previous_limit
    RecordingStudioEmbeddable.configuration.rate_limiter = previous_limiter if previous_limiter
  end

  private

  def assert_hidden_popup(path, headers, title)
    https!
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
      parent_recording: @widget,
      actor: @user,
      attributes: { slug: "popup-widget-#{SecureRandom.hex(3)}", status: "published" }
    )
    raise result.error unless result.success?
  end
end
