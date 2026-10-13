# frozen_string_literal: true

require "test_helper"

class PublicEmbedRateLimitTest < ActionDispatch::IntegrationTest
  setup do
    @previous = {
      rate_limiting_enabled: RecordingStudioEmbeddable.configuration.rate_limiting_enabled,
      rate_limiter: RecordingStudioEmbeddable.configuration.rate_limiter,
      rate_limit: RecordingStudioEmbeddable.configuration.rate_limit,
      rate_limit_window: RecordingStudioEmbeddable.configuration.rate_limit_window,
      rate_limit_fail_closed: RecordingStudioEmbeddable.configuration.rate_limit_fail_closed
    }
    @previous_cache = Rails.cache
    # Test env defaults to NullStore (no persistent counters). Use MemoryStore so
    # the shared rails_cache backend can enforce the fixed window.
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = true
    RecordingStudioEmbeddable.configuration.rate_limiter = :rails_cache
    RecordingStudioEmbeddable.configuration.rate_limit = 2
    RecordingStudioEmbeddable.configuration.rate_limit_window = 60
    RecordingStudioEmbeddable.configuration.rate_limit_fail_closed = false
  end

  teardown do
    @previous.each do |key, value|
      RecordingStudioEmbeddable.configuration.public_send("#{key}=", value)
    end
    Rails.cache = @previous_cache
  end

  test "public embed returns 429 with Retry-After after the configured limit" do
    token = "rate-limit-token"
    path = "/recording_studio_embeddable/embeds/#{token}"

    get path
    get path
    get path

    assert_response :too_many_requests
    assert_equal "60", response.headers["Retry-After"]
  end

  test "rate limiting can be disabled without changing other config" do
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = false

    get "/recording_studio_embeddable/embeds/rate-limit-disabled-token"

    assert_response :not_found
    refute_equal "60", response.headers["Retry-After"]
  end
end

