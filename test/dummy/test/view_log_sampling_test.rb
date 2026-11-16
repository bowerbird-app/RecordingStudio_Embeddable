# frozen_string_literal: true

require "test_helper"
require "active_job/test_helper"

class ViewLogSamplingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @previous_async = RecordingStudioEmbeddable.configuration.async_view_logging
    @previous_rate = RecordingStudioEmbeddable.configuration.view_log_success_sample_rate
    @previous_logging = RecordingStudioEmbeddable.configuration.view_logging_enabled
    RecordingStudioEmbeddable.configuration.view_logging_enabled = true
    RecordingStudioEmbeddable.configuration.async_view_logging = true
    RecordingStudioEmbeddable::EmbeddableViewLog.delete_all
    clear_enqueued_jobs
  end

  teardown do
    RecordingStudioEmbeddable.configuration.async_view_logging = @previous_async
    RecordingStudioEmbeddable.configuration.view_log_success_sample_rate = @previous_rate
    RecordingStudioEmbeddable.configuration.view_logging_enabled = @previous_logging
  end

  test "sample rate 0 writes no row and enqueues no job" do
    RecordingStudioEmbeddable.configuration.view_log_success_sample_rate = 0

    assert_no_difference -> { RecordingStudioEmbeddable::EmbeddableViewLog.count } do
      assert_no_enqueued_jobs only: RecordingStudioEmbeddable::LogViewJob do
        capture_view
      end
    end
  end

  test "sample rate 1 writes one row with that rate" do
    RecordingStudioEmbeddable.configuration.view_log_success_sample_rate = 1
    RecordingStudioEmbeddable.configuration.async_view_logging = false

    assert_difference -> { RecordingStudioEmbeddable::EmbeddableViewLog.count }, 1 do
      capture_view
    end

    assert_in_delta 1.0, RecordingStudioEmbeddable::EmbeddableViewLog.last.metadata["sample_rate"].to_f
  end

  test "sample rate 1 enqueues one job and the job stores the rate" do
    RecordingStudioEmbeddable.configuration.view_log_success_sample_rate = 1

    assert_enqueued_jobs 1, only: RecordingStudioEmbeddable::LogViewJob do
      assert_no_difference -> { RecordingStudioEmbeddable::EmbeddableViewLog.count } do
        capture_view
      end
    end

    perform_enqueued_jobs(only: RecordingStudioEmbeddable::LogViewJob)

    assert_equal 1, RecordingStudioEmbeddable::EmbeddableViewLog.count
    assert_in_delta 1.0, RecordingStudioEmbeddable::EmbeddableViewLog.last.metadata["sample_rate"].to_f
  end

  test "sample rate 0.1 writes one view in ten" do
    RecordingStudioEmbeddable.configuration.view_log_success_sample_rate = 0.1

    draws = (0..9).map { |step| step / 10.0 }
    capture = RecordingStudioEmbeddable::Services::CaptureView
    capture.define_singleton_method(:random_draw) { draws.shift }

    assert_enqueued_jobs 1, only: RecordingStudioEmbeddable::LogViewJob do
      10.times { capture_view }
    end

    perform_enqueued_jobs(only: RecordingStudioEmbeddable::LogViewJob)

    assert_equal 1, RecordingStudioEmbeddable::EmbeddableViewLog.count
    assert_in_delta 0.1, RecordingStudioEmbeddable::EmbeddableViewLog.last.metadata["sample_rate"].to_f
  ensure
    RecordingStudioEmbeddable::Services::CaptureView.define_singleton_method(:random_draw) { Kernel.rand }
  end

  private

  def capture_view
    RecordingStudioEmbeddable::Services::CaptureView.call(
      embed: nil,
      request: ActionDispatch::TestRequest.create,
      status: "rendered",
      status_code: 200
    )
  end
end

class PublicEmbedNotModifiedViewLogTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @previous = {
      async_view_logging: RecordingStudioEmbeddable.configuration.async_view_logging,
      view_log_success_sample_rate: RecordingStudioEmbeddable.configuration.view_log_success_sample_rate,
      view_logging_enabled: RecordingStudioEmbeddable.configuration.view_logging_enabled,
      public_embeds_enabled: RecordingStudioEmbeddable.configuration.public_embeds_enabled,
      allow_any_domain: RecordingStudioEmbeddable.configuration.allow_any_domain,
      require_publishable: RecordingStudioEmbeddable.configuration.require_publishable,
      rate_limiting_enabled: RecordingStudioEmbeddable.configuration.rate_limiting_enabled,
      cache_policy: RecordingStudioEmbeddable.configuration.cache_policy
    }
    RecordingStudioEmbeddable.configuration.public_embeds_enabled = true
    RecordingStudioEmbeddable.configuration.allow_any_domain = true
    RecordingStudioEmbeddable.configuration.require_publishable = false
    RecordingStudioEmbeddable.configuration.rate_limiting_enabled = false
    RecordingStudioEmbeddable.configuration.view_logging_enabled = true
    RecordingStudioEmbeddable.configuration.view_log_success_sample_rate = 1
    RecordingStudioEmbeddable.configuration.async_view_logging = true
    RecordingStudioEmbeddable.configuration.cache_policy = {
      enabled: true, public: true, max_age: 300, stale_while_revalidate: 60
    }
  end

  teardown do
    @previous.each do |key, value|
      RecordingStudioEmbeddable.configuration.public_send("#{key}=", value)
    end
    Current.actor = nil if defined?(Current)
  end

  test "304 responses write nothing and enqueue no job" do
    path, headers = published_embed_request

    assert_enqueued_jobs 1, only: RecordingStudioEmbeddable::LogViewJob do
      get path, headers: headers
    end
    assert_response :success
    etag = response.headers["ETag"]
    assert etag.present?

    assert_no_difference -> { RecordingStudioEmbeddable::EmbeddableViewLog.count } do
      assert_no_enqueued_jobs only: RecordingStudioEmbeddable::LogViewJob do
        get path, headers: headers.merge("If-None-Match" => etag)
      end
    end
    assert_response :not_modified
  end

  private

  def published_embed_request
    user = User.create!(
      email: "embed-304-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    Current.actor = user
    workspace = Workspace.create!(name: "Not modified #{SecureRandom.hex(4)}")
    root = RecordingStudio.create_root_recording!(workspace, actor: user)
    page = root.record(Page, actor: user) { |record| record.title = "Not modified page" }
    embed = page.ensure_embed!(actor: user, enabled: true, allowed_embedder_domains: ["example.com"])
    unless page.currently_published?
      publish = RecordingStudioPublishable::Services::Publishables::Update.call(
        parent_recording: page,
        actor: user,
        attributes: { slug: "not-modified-#{SecureRandom.hex(3)}", status: "published" }
      )
      raise publish.error unless publish.success?
    end

    ["/recording_studio_embeddable/embeds/#{embed.token}", { "Origin" => "https://example.com" }]
  end
end
