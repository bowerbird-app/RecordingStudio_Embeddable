# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"

class PublicEmbedRateLimitTest < ActionDispatch::IntegrationTest
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
    @previous = {
      rate_limiting_enabled: RecordingStudioEmbeddable.configuration.rate_limiting_enabled,
      rate_limiter: RecordingStudioEmbeddable.configuration.rate_limiter,
      rate_limit: RecordingStudioEmbeddable.configuration.rate_limit,
      rate_limit_window: RecordingStudioEmbeddable.configuration.rate_limit_window,
      per_ip_rate_limit: RecordingStudioEmbeddable.configuration.per_ip_rate_limit,
      per_ip_rate_limit_window: RecordingStudioEmbeddable.configuration.per_ip_rate_limit_window,
      invalid_token_rate_limit: RecordingStudioEmbeddable.configuration.invalid_token_rate_limit,
      invalid_token_rate_limit_window: RecordingStudioEmbeddable.configuration.invalid_token_rate_limit_window,
      invalid_token_log_sample_rate: RecordingStudioEmbeddable.configuration.invalid_token_log_sample_rate,
      rate_limit_fail_closed: RecordingStudioEmbeddable.configuration.rate_limit_fail_closed,
      async_view_logging: RecordingStudioEmbeddable.configuration.async_view_logging,
      public_embeds_enabled: RecordingStudioEmbeddable.configuration.public_embeds_enabled,
      allow_any_domain: RecordingStudioEmbeddable.configuration.allow_any_domain,
      require_publishable: RecordingStudioEmbeddable.configuration.require_publishable
    }
    @previous_cache = Rails.cache
    @previous_logger = Rails.logger
    # Test env defaults to NullStore (no persistent counters). Use MemoryStore so
    # the shared rails_cache backend can enforce the fixed window.
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = true
    RecordingStudioEmbeddable.configuration.rate_limiter = :rails_cache
    RecordingStudioEmbeddable.configuration.rate_limit = 2
    RecordingStudioEmbeddable.configuration.rate_limit_window = 60
    RecordingStudioEmbeddable.configuration.per_ip_rate_limit = 600
    RecordingStudioEmbeddable.configuration.per_ip_rate_limit_window = 60
    RecordingStudioEmbeddable.configuration.invalid_token_rate_limit = 30
    RecordingStudioEmbeddable.configuration.invalid_token_rate_limit_window = 60
    RecordingStudioEmbeddable.configuration.invalid_token_log_sample_rate = 0
    RecordingStudioEmbeddable.configuration.rate_limit_fail_closed = false
    RecordingStudioEmbeddable.configuration.async_view_logging = true
  end

  teardown do
    @previous.each do |key, value|
      RecordingStudioEmbeddable.configuration.public_send("#{key}=", value)
    end
    Rails.cache = @previous_cache
    Rails.logger = @previous_logger
    Current.actor = nil if defined?(Current)
  end

  test "public embed returns 429 with Retry-After after the configured limit" do
    token = "rate-limit-token"
    path = "/recording_studio_embeddable/embeds/#{token}"

    get path
    get path
    assert_no_view_log { get path }

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  test "rate limiting can be disabled without changing other config" do
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = false

    assert_no_view_log do
      get "/recording_studio_embeddable/embeds/rate-limit-disabled-token"
    end

    assert_response :not_found
    refute_equal "60", response.headers["Retry-After"]
  end

  test "many random tokens from one IP are limited before another lookup" do
    RecordingStudioEmbeddable.configuration.per_ip_rate_limit = 100
    RecordingStudioEmbeddable.configuration.rate_limit = 100
    RecordingStudioEmbeddable.configuration.invalid_token_rate_limit = 3
    RecordingStudioEmbeddable.configuration.invalid_token_rate_limit_window = 45
    RecordingStudioEmbeddable.configuration.async_view_logging = false

    3.times do |index|
      assert_no_view_log do
        get "/recording_studio_embeddable/embeds/missing-#{index}-#{SecureRandom.hex(4)}",
            env: { "REMOTE_ADDR" => "203.0.113.10" }
      end
      assert_response :not_found
    end

    queries = embed_queries do
      assert_no_view_log do
        get "/recording_studio_embeddable/embeds/missing-over-#{SecureRandom.hex(4)}",
            env: { "REMOTE_ADDR" => "203.0.113.10" }
      end
    end

    assert_response :too_many_requests
    assert_equal "45", response.headers["Retry-After"]
    assert_empty queries
  end

  test "per IP limit is checked before the token lookup" do
    RecordingStudioEmbeddable.configuration.per_ip_rate_limit = 2
    RecordingStudioEmbeddable.configuration.per_ip_rate_limit_window = 30
    RecordingStudioEmbeddable.configuration.invalid_token_rate_limit = 50
    RecordingStudioEmbeddable.configuration.rate_limit = 50

    2.times do |index|
      get "/recording_studio_embeddable/embeds/ip-budget-#{index}",
          env: { "REMOTE_ADDR" => "203.0.113.11" }
      assert_response :not_found
    end

    queries = embed_queries do
      assert_no_view_log do
        get "/recording_studio_embeddable/embeds/ip-budget-over",
            env: { "REMOTE_ADDR" => "203.0.113.11" }
      end
    end

    assert_response :too_many_requests
    assert_equal "30", response.headers["Retry-After"]
    assert_empty queries
  end

  test "a different token keeps its own token budget" do
    RecordingStudioEmbeddable.configuration.rate_limit = 1
    RecordingStudioEmbeddable.configuration.per_ip_rate_limit = 20
    RecordingStudioEmbeddable.configuration.invalid_token_rate_limit = 20

    get "/recording_studio_embeddable/embeds/token-a"
    assert_response :not_found

    assert_no_view_log { get "/recording_studio_embeddable/embeds/token-a" }
    assert_response :too_many_requests

    get "/recording_studio_embeddable/embeds/token-b"
    assert_response :not_found
  end

  test "limiter keys are digests and never contain the raw token" do
    seen = []
    limiter = Object.new
    limiter.define_singleton_method(:allow?) do |key:, limit:, window:|
      seen << { key: key.to_s, limit: limit, window: window }
      true
    end
    RecordingStudioEmbeddable.configuration.rate_limiter = limiter
    token = "raw-token-should-not-leak"
    ip = "203.0.113.12"

    get "/recording_studio_embeddable/embeds/#{token}", env: { "REMOTE_ADDR" => ip }

    assert_response :not_found
    refute_empty seen
    seen.each do |call|
      refute_includes call[:key], token
      refute_includes call[:key], ip
    end
    assert_includes seen.map { |call| call[:key] },
                    "public-ip:#{RecordingStudioEmbeddable::Services::LogView.digest(ip)}"
    assert_includes seen.map { |call| call[:key] },
                    "public-ip-miss:#{RecordingStudioEmbeddable::Services::LogView.digest(ip)}"
    assert_includes seen.map { |call| call[:key] },
                    RecordingStudioEmbeddable::Services::LogView.digest("#{token}:#{ip}")
  end

  test "rejected requests log a sampled line without the token" do
    token = "visible-token-value"
    ip = "203.0.113.13"
    io = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(io)
    RecordingStudioEmbeddable.configuration.invalid_token_log_sample_rate = 1

    get "/recording_studio_embeddable/embeds/#{token}", env: { "REMOTE_ADDR" => ip }

    assert_response :not_found
    rejection = io.string.lines.grep(/public embed rejected/).join
    refute_includes rejection, token
    refute_includes rejection, ip
    assert_match(/reason=invalid_token/, rejection)
    assert_match(/ip_digest=#{RecordingStudioEmbeddable::Services::LogView.digest(ip)}/, rejection)

    quiet = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(quiet)
    RecordingStudioEmbeddable.configuration.invalid_token_log_sample_rate = 0
    get "/recording_studio_embeddable/embeds/#{token}-quiet", env: { "REMOTE_ADDR" => ip }
    assert_empty quiet.string.lines.grep(/public embed rejected/)
  end

  test "a limiter read error follows rate_limit_fail_closed before lookup" do
    limiter = Object.new
    limiter.define_singleton_method(:allow?) { |**| true }
    limiter.define_singleton_method(:count) { |**| raise StandardError, "cache down" }
    RecordingStudioEmbeddable.configuration.rate_limiter = limiter
    RecordingStudioEmbeddable.configuration.rate_limit_fail_closed = true

    queries = embed_queries do
      get "/recording_studio_embeddable/embeds/fail-closed-token"
    end

    assert_response :too_many_requests
    assert_empty queries

    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioEmbeddable.configuration.rate_limit_fail_closed = false
    get "/recording_studio_embeddable/embeds/fail-open-token"
    assert_response :not_found
  end

  test "a null limiter does not block misses" do
    RecordingStudioEmbeddable.configuration.rate_limiter = :null
    RecordingStudioEmbeddable.configuration.invalid_token_rate_limit = 1
    RecordingStudioEmbeddable.configuration.per_ip_rate_limit = 1

    3.times do |index|
      get "/recording_studio_embeddable/embeds/null-limiter-#{index}"
      assert_response :not_found
    end
  end

  test "a valid embed still renders and logs under normal load" do
    RecordingStudioEmbeddable.configuration.public_embeds_enabled = true
    RecordingStudioEmbeddable.configuration.allow_any_domain = true
    RecordingStudioEmbeddable.configuration.require_publishable = false
    RecordingStudioEmbeddable.configuration.rate_limit = 20
    RecordingStudioEmbeddable.configuration.per_ip_rate_limit = 20
    RecordingStudioEmbeddable.configuration.invalid_token_rate_limit = 1
    user = User.create!(
      email: "embed-rate-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = user
    workspace = Workspace.create!(name: "Embed rate #{SecureRandom.hex(4)}")
    root = RecordingStudio.create_root_recording!(workspace, actor: user)
    page = root.record(Page, actor: user) { |record| record.title = "Rate limit page" }
    embed = page.ensure_embed!(actor: user, enabled: true, allowed_embedder_domains: ["example.com"])
    unless page.currently_published?
      publish = RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: page,
        actor: user,
        attributes: { slug: "rate-limit-page-#{SecureRandom.hex(3)}", status: "published" }
      )
      raise publish.error unless publish.success?
    end
    path = "/recording_studio_embeddable/embeds/#{embed.token}"
    headers = { "Origin" => "https://example.com" }

    assert_enqueued_jobs 1, only: RecordingStudioEmbeddable::LogViewJob do
      get path, headers: headers
    end
    assert_response :success

    assert_enqueued_jobs 1, only: RecordingStudioEmbeddable::LogViewJob do
      get path, headers: headers
    end
    assert_response :success

    get "/recording_studio_embeddable/embeds/still-under-miss-budget"
    assert_response :not_found

    queries = embed_queries do
      get "/recording_studio_embeddable/embeds/miss-budget-spent"
    end
    assert_response :too_many_requests
    assert_empty queries

    RecordingStudioEmbeddable::Embed.where(id: embed.id).update_all(enabled: false)
    Rails.cache.clear
    RecordingStudioEmbeddable.configuration.invalid_token_rate_limit = 30

    get "/recording_studio_embeddable/embeds/disabled-parent-unknown"
    unknown_body = response.body
    unknown_headers = comparable_headers

    get path
    assert_response :not_found
    assert_equal unknown_body, response.body
    assert_equal unknown_headers, comparable_headers
    refute_includes response.body, embed.token
  end

  private

  def comparable_headers
    RESPONSE_HEADERS.index_with { |name| response.headers[name] }
  end

  def assert_no_view_log(&)
    assert_no_difference -> { RecordingStudioEmbeddable::EmbeddableViewLog.count } do
      assert_no_enqueued_jobs only: RecordingStudioEmbeddable::LogViewJob, &
    end
  end

  def embed_queries
    queries = []
    callback = lambda do |_name, _started, _finished, _id, payload|
      sql = payload[:sql].to_s
      queries << sql if sql.match?(/recording_studio_embeddable_embeds/i)
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
