# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"

class PublicEmbedAllowedTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  RESPONSE_HEADERS = %w[
    Content-Security-Policy
    X-Frame-Options
    Cache-Control
    X-Content-Type-Options
    Referrer-Policy
    Permissions-Policy
    Vary
    Retry-After
    Content-Type
  ].freeze

  setup do
    @previous = %i[
      public_embeds_enabled
      allow_any_domain
      require_domain_allowlist
      rate_limiting_enabled
      view_logging_enabled
      view_log_success_sample_rate
    ].index_with { |key| RecordingStudioEmbeddable.configuration.public_send(key) }

    RecordingStudioEmbeddable.configuration.public_embeds_enabled = true
    RecordingStudioEmbeddable.configuration.allow_any_domain = true
    RecordingStudioEmbeddable.configuration.require_domain_allowlist = false
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = false
    RecordingStudioEmbeddable.configuration.view_logging_enabled = true
    RecordingStudioEmbeddable.configuration.view_log_success_sample_rate = 1

    @user = User.create!(
      email: "embed-allowed-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = @user
    workspace = Workspace.create!(name: "Embed allowed #{SecureRandom.hex(4)}")
    root = RecordingStudio.create_root_recording!(workspace, actor: @user)

    @page = root.record(Page, actor: @user) { |record| record.title = "Public page #{SecureRandom.hex(4)}" }
    @page_embed = @page.ensure_embed!(actor: @user, enabled: true, allowed_embedder_domains: ["example.com"])
    publish!(@page)

    @widget = root.record(Widget, actor: @user) { |record| record.title = "Public widget #{SecureRandom.hex(4)}" }
    @widget_embed = @widget.ensure_embed!(
      actor: @user,
      enabled: true,
      floating_enabled: true,
      allowed_embedder_domains: ["example.com"]
    )
    @headers = { "Origin" => "https://example.com" }
  end

  teardown do
    @previous.each { |key, value| RecordingStudioEmbeddable.configuration.public_send("#{key}=", value) }
    remove_public_embed_allowed(Page)
    remove_public_embed_allowed(Widget)
    Current.actor = nil
  end

  test "a recordable without the hook still embeds" do
    assert_enqueued_jobs 1, only: RecordingStudioEmbeddable::LogViewJob do
      get iframe_path, headers: @headers
    end
    assert_response :success
    assert_includes response.body, @page.recordable.title

    get launcher_path, headers: @headers
    assert_response :success
    assert_includes response.body, @widget.recordable.title

    get popup_path, headers: { "Referer" => "https://example.com/page" }
    assert_response :success
    assert_includes response.body, @widget.recordable.title
  end

  test "a recordable that returns false gets no iframe, launcher, or popup" do
    unknown = unknown_embed

    with_public_embed_allowed(Page, ->(viewer:) { false }) do
      assert_no_view_log { get iframe_path, headers: @headers }
    end
    assert_response :not_found
    assert_equal unknown[:body], response.body
    assert_equal unknown[:headers], comparable_headers
    refute_includes response.body, @page_embed.token
    refute_includes response.body, @page.recordable.title

    with_public_embed_allowed(Widget, ->(viewer:) { false }) do
      get launcher_path, headers: @headers
      assert_response :not_found
      assert_empty response.body
      refute_includes response.body, @widget.recordable.title

      get popup_path, headers: { "Referer" => "https://example.com/page" }
      assert_response :not_found
      assert_empty response.body
      refute_includes response.body, @widget.recordable.title
    end
  end

  test "a recordable that raises is refused and the error stays out of the response" do
    warnings = capture_warnings do
      with_public_embed_allowed(Page, ->(viewer:) { raise "secret boom" }) do
        assert_no_view_log { get iframe_path, headers: @headers }
      end
    end

    assert_response :not_found
    refute_includes response.body, "secret boom"
    refute_includes response.body, @page.recordable.title
    assert_includes warnings, "RuntimeError"
    refute_includes warnings, "secret boom"

    warnings = capture_warnings do
      with_public_embed_allowed(Widget, ->(viewer:) { raise "secret boom" }) do
        get launcher_path, headers: @headers
        assert_response :not_found
        assert_empty response.body

        get popup_path, headers: { "Referer" => "https://example.com/page" }
        assert_response :not_found
        assert_empty response.body
      end
    end

    refute_includes response.body, "secret boom"
    assert_includes warnings, "RuntimeError"
    refute_includes warnings, "secret boom"
  end

  test "a recordable that defines the hook is not publicly cached" do
    previous_cache = RecordingStudioEmbeddable.configuration.cache_policy
    RecordingStudioEmbeddable.configuration.cache_policy = {
      enabled: true, public: true, max_age: 300, stale_while_revalidate: 60
    }

    get iframe_path, headers: @headers
    assert_response :success
    etag = response.headers["ETag"]
    assert etag.present?
    assert_includes response.headers["Cache-Control"], "public"

    get iframe_path, headers: @headers.merge("If-None-Match" => etag)
    assert_response :not_modified

    with_public_embed_allowed(Page, ->(viewer:) { true }) do
      get iframe_path, headers: @headers.merge("If-None-Match" => etag)
      assert_response :success
      assert_includes response.headers["Cache-Control"], "no-store"
      refute_includes response.headers["Cache-Control"], "public"
      assert_includes response.body, @page.recordable.title
    end
  ensure
    RecordingStudioEmbeddable.configuration.cache_policy = previous_cache
  end

  test "a recordable that allows the embed receives a nil viewer" do
    seen = :missing
    with_public_embed_allowed(Page, lambda { |viewer:|
      seen = viewer
      true
    }) do
      get iframe_path, headers: @headers
    end

    assert_response :success
    assert_nil seen
    assert_includes response.body, @page.recordable.title
  end

  private

  def iframe_path
    "/recording_studio_embeddable/embeds/#{@page_embed.token}"
  end

  def launcher_path
    "/recording_studio_embeddable/embeds/#{@widget_embed.token}/launcher"
  end

  def popup_path
    "/widgets/#{@widget_embed.token}"
  end

  def publish!(recording)
    return if recording.currently_published?

    result = RecordingStudioPublishable::Services::Publishables::Update.call(
      parent_recording: recording,
      actor: @user,
      attributes: { slug: "embed-allowed-#{SecureRandom.hex(3)}", status: "published" }
    )
    raise result.error unless result.success?
  end

  def with_public_embed_allowed(model, hook)
    model.define_method(:public_embed_allowed?, hook)
    yield
  ensure
    remove_public_embed_allowed(model)
  end

  def remove_public_embed_allowed(model)
    return unless model.instance_methods(false).include?(:public_embed_allowed?)

    model.remove_method(:public_embed_allowed?)
  end

  def unknown_embed
    get "/recording_studio_embeddable/embeds/missing-token-#{SecureRandom.hex(4)}"
    assert_response :not_found
    { body: response.body, headers: comparable_headers }
  end

  def comparable_headers
    RESPONSE_HEADERS.index_with { |name| response.headers[name] }
  end

  def capture_warnings
    io = StringIO.new
    previous = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = previous
  end

  def assert_no_view_log(&)
    assert_no_difference -> { RecordingStudioEmbeddable::EmbeddableViewLog.count } do
      assert_no_enqueued_jobs only: RecordingStudioEmbeddable::LogViewJob, &
    end
  end
end
