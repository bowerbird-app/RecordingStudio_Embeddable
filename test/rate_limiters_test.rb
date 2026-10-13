# frozen_string_literal: true

require "test_helper"
require "active_support/cache"
require "active_support/testing/time_helpers"

class RateLimitersTest < Minitest::Test
  include ActiveSupport::Testing::TimeHelpers

  def setup
    RecordingStudioEmbeddable.reset_configuration!
    @previous_cache = Rails.cache if defined?(Rails) && Rails.respond_to?(:cache)
    @memory = ActiveSupport::Cache::MemoryStore.new
    Rails.cache = @memory
  end

  def teardown
    travel_back
    Rails.cache = @previous_cache if defined?(Rails) && Rails.respond_to?(:cache=)
    RecordingStudioEmbeddable.reset_configuration!
  end

  def test_null_always_allows
    RecordingStudioEmbeddable.configuration.rate_limiter = :null

    5.times do
      assert RecordingStudioEmbeddable::RateLimiters::Null.allow?(
        key: "anyone",
        limit: 1,
        window: 60
      )
    end
  end

  def test_rails_cache_fixed_window_key_shape_and_limit
    travel_to Time.parse("2026-10-13 12:00:30 UTC")
    window = 60
    bucket = Time.current.to_i / window
    key = "token-digest"

    assert RecordingStudioEmbeddable::RateLimiters::RailsCache.allow?(
      key: key, limit: 2, window: window
    )
    assert RecordingStudioEmbeddable::RateLimiters::RailsCache.allow?(
      key: key, limit: 2, window: window
    )
    refute RecordingStudioEmbeddable::RateLimiters::RailsCache.allow?(
      key: key, limit: 2, window: window
    )

    expected = "recording_studio_embeddable:rate:#{key}:#{bucket}"
    assert @memory.exist?(expected), "expected cache key #{expected}"
    assert_equal 3, @memory.read(expected).to_i
  end

  def test_rails_cache_window_resets_on_next_bucket
    travel_to Time.parse("2026-10-13 12:00:00 UTC")
    opts = { key: "fixed", limit: 1, window: 60 }

    assert RecordingStudioEmbeddable::RateLimiters::RailsCache.allow?(**opts)
    refute RecordingStudioEmbeddable::RateLimiters::RailsCache.allow?(**opts)

    travel_to Time.parse("2026-10-13 12:01:00 UTC")
    assert RecordingStudioEmbeddable::RateLimiters::RailsCache.allow?(**opts)
  end

  def test_rails_cache_fail_open_and_fail_closed_on_store_errors
    broken = Object.new
    def broken.increment(*)
      raise StandardError, "cache down"
    end
    Rails.cache = broken

    RecordingStudioEmbeddable.configuration.rate_limit_fail_closed = false
    assert RecordingStudioEmbeddable::RateLimiters::RailsCache.allow?(
      key: "err", limit: 1, window: 60
    )

    RecordingStudioEmbeddable.configuration.rate_limit_fail_closed = true
    refute RecordingStudioEmbeddable::RateLimiters::RailsCache.allow?(
      key: "err", limit: 1, window: 60
    )
  end

  def test_redis_adapter_uses_eval_client_and_config_redis
    redis = FakeEvalRedis.new
    RecordingStudioEmbeddable.configuration.redis = redis
    RecordingStudioEmbeddable.configuration.rate_limiter = :redis

    travel_to Time.parse("2026-10-13 12:00:30 UTC")
    window = 60
    bucket = Time.current.to_i / window
    key = "embed-key"

    assert RecordingStudioEmbeddable::RateLimiters::Redis.allow?(
      key: key, limit: 1, window: window
    )
    refute RecordingStudioEmbeddable::RateLimiters::Redis.allow?(
      key: key, limit: 1, window: window
    )

    expected = "recording_studio_embeddable:rate:#{key}:#{bucket}"
    assert_equal [expected], redis.keys
    assert_equal 2, redis.counts[expected]
  end

  def test_redis_adapter_falls_back_to_rate_limiter_client_with_incr
    redis = FakeEvalRedis.new
    RecordingStudioEmbeddable.configuration.redis = nil
    RecordingStudioEmbeddable.configuration.rate_limiter = redis

    assert RecordingStudioEmbeddable::RateLimiters::Redis.allow?(
      key: "via-limiter", limit: 5, window: 60
    )
    assert_predicate redis.keys, :any?
  end

  def test_redis_incr_only_client_raises_argument_error
    incr_only = IncrOnlyRedis.new
    RecordingStudioEmbeddable.configuration.redis = incr_only
    RecordingStudioEmbeddable.configuration.rate_limiter = :redis

    error = assert_raises(ArgumentError) do
      RecordingStudioEmbeddable::RateLimiters::Redis.allow?(
        key: "legacy", limit: 1, window: 60
      )
    end
    assert_match(/responds to eval/, error.message)
  end

  def test_instance_allow_delegates_to_class
    assert RecordingStudioEmbeddable::RateLimiters::Null.new.allow?(
      key: "x", limit: 1, window: 60
    )
    assert RecordingStudioEmbeddable::RateLimiters::RailsCache.new.allow?(
      key: "y", limit: 5, window: 60
    )
  end

  # Minimal Redis-compatible client: responds to +eval+ (required by shared limiter).
  class FakeEvalRedis
    attr_reader :counts, :keys

    def initialize
      @counts = Hash.new(0)
      @ttls = {}
      @keys = []
    end

    def eval(_script, keys:, argv:)
      storage_key = keys.fetch(0)
      expires_in = argv.fetch(0).to_i
      @counts[storage_key] += 1
      @keys << storage_key unless @keys.include?(storage_key)
      count = @counts[storage_key]
      @ttls[storage_key] = expires_in if count == 1 || !@ttls.key?(storage_key)
      [count, @ttls[storage_key]]
    end

    def incr(*)
      raise "incr should not be used; shared limiter requires eval"
    end
  end

  # Legacy shape: +incr+/+expire+ only (no +eval+) — shared limiter rejects this.
  class IncrOnlyRedis
    def incr(*)
      1
    end

    def expire(*)
      "OK"
    end
  end
end
