# frozen_string_literal: true

require "test_helper"

class EmbeddableViewLogLogsTest < ActiveSupport::TestCase
  setup do
    RecordingStudioEmbeddable.reset_configuration!
    RecordingStudioEmbeddable.configuration.logs_summaries_enabled = false
    RecordingStudioEmbeddable::LogsRegistration.register!
    RecordingStudioEmbeddable::EmbeddableViewLog.delete_all
    RecordingStudioEmbeddable::EmbeddableViewDaySummary.delete_all
    clear_runs!
    @day = Date.new(2026, 10, 1)
    @root_id = SecureRandom.uuid
    @embed_id = SecureRandom.uuid
  end

  teardown do
    RecordingStudioEmbeddable.reset_configuration!
  end

  test "raw view log table stays unpartitioned with a uuid primary key" do
    connection = RecordingStudioEmbeddable::EmbeddableViewLog.connection
    table = "recording_studio_embeddable_view_logs"
    relkind = connection.select_value("SELECT relkind FROM pg_class WHERE relname = #{connection.quote(table)}")

    assert_equal "r", relkind
    assert_equal "id", connection.primary_key(table)
    type = connection.select_value(<<~SQL.squish)
      SELECT data_type FROM information_schema.columns
      WHERE table_name = #{connection.quote(table)} AND column_name = 'id'
    SQL
    assert_equal "uuid", type
    assert connection.column_exists?(table, :root_recording_id)
    assert connection.column_exists?(table, :arrived_at)
    assert connection.data_source_exists?("recording_studio_logs_aggregation_runs")
    assert connection.data_source_exists?("recording_studio_embeddable_view_day_summaries")
  end

  test "log view stamps root from the parent recording" do
    user = User.find_or_create_by!(email: "view-log-logs@example.test") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    Current.actor = user
    workspace = Workspace.create!(name: "Logs #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    page = root.record(Page, actor: user) { |record| record.title = "Logged page" }
    embed = page.ensure_embed!(enabled: true)

    RecordingStudioEmbeddable::Services::LogView.call(
      embed: embed,
      payload: { ip: "127.0.0.1", user_agent: "Mozilla/5.0", referer: "https://example.com/kit" },
      status: "rendered",
      status_code: 200
    )

    row = RecordingStudioEmbeddable::EmbeddableViewLog.order(:created_at).last
    assert_equal root.id, row.root_recording_id
    assert_equal page.id, row.parent_recording_id
    assert_equal embed.id, row.embed_id
    assert_nil row.remote_ip
    assert row.arrived_at.present?
  ensure
    Current.actor = nil
  end

  test "prune views job still deletes old rows when summaries are off" do
    insert_log(viewed_at: Time.utc(2026, 6, 1, 12))
    insert_log(viewed_at: Time.utc(2026, 10, 20, 12))

    RecordingStudioEmbeddable::PruneViewsJob.perform_now(before: Time.utc(2026, 7, 1))

    assert_equal 1, RecordingStudioEmbeddable::EmbeddableViewLog.count
    assert_equal Time.utc(2026, 10, 20, 12), RecordingStudioEmbeddable::EmbeddableViewLog.first.viewed_at
  end

  test "summaries rebuild counts and block prune until the day is covered" do
    RecordingStudioEmbeddable.configuration.logs_summaries_enabled = true
    insert_log(viewed_at: Time.utc(2026, 10, 1, 12), status: "rendered")
    insert_log(viewed_at: Time.utc(2026, 10, 1, 18), status: "not_found")

    RecordingStudioEmbeddable::PruneViewsJob.perform_now(before: Time.utc(2026, 10, 18))
    assert_equal 2, RecordingStudioEmbeddable::EmbeddableViewLog.count

    RecordingStudioEmbeddable::Services::RebuildEmbeddableViewLogSummaries.call(day: @day)
    summaries = RecordingStudioEmbeddable::EmbeddableViewDaySummary.where(day: @day)
    assert_equal 2, summaries.sum(:view_count)
    assert_equal 1, summaries.where(status: "rendered").sum(:view_count)

    RecordingStudioEmbeddable::Services::RebuildEmbeddableViewLogSummaries.call(day: @day)
    assert_equal 2, RecordingStudioEmbeddable::EmbeddableViewDaySummary.where(day: @day).sum(:view_count)

    RecordingStudioEmbeddable::PruneViewsJob.perform_now(before: Time.utc(2026, 10, 18))
    assert_equal 0, RecordingStudioEmbeddable::EmbeddableViewLog.count
  end

  test "stats still read raw view logs while summaries stay off" do
    RecordingStudioEmbeddable.configuration.logs_summaries_enabled = false
    insert_log(viewed_at: Time.utc(2026, 10, 1, 12), status: "rendered")
    RecordingStudioEmbeddable::Services::RebuildEmbeddableViewLogSummaries.call(day: @day)

    summary = RecordingStudioEmbeddable::EmbeddableViewLog.summary_for(nil)
    assert_equal 1, summary.fetch(:total)
    assert_equal false, RecordingStudioEmbeddable.configuration.logs_summaries_enabled
  end

  private

  def insert_log(viewed_at:, status: "rendered")
    RecordingStudioEmbeddable::EmbeddableViewLog.create!(
      embed_id: nil,
      root_recording_id: @root_id,
      parent_recording_id: SecureRandom.uuid,
      status: status,
      viewed_at: viewed_at,
      arrived_at: viewed_at,
      bot: false,
      cache_hit: false,
      rate_limited: false
    )
  end

  def clear_runs!
    connection = RecordingStudioEmbeddable::LogsRegistration.logging_connection
    return unless connection.data_source_exists?("recording_studio_logs_aggregation_runs")

    connection.execute("DELETE FROM #{connection.quote_table_name('recording_studio_logs_aggregation_runs')}")
  end

end
