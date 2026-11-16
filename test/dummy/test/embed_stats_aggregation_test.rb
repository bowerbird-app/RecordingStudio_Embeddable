# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class EmbedStatsAggregationTest < ActiveSupport::TestCase
  setup do
    RecordingStudioEmbeddable::EmbeddableViewLog.delete_all
    @root_id = SecureRandom.uuid
    @sampled_root_id = SecureRandom.uuid
  end

  test "per day week and month counts match the previous ruby grouping" do
    insert_view(viewed_at: Time.utc(2026, 11, 1, 12), digest: "same", country: "AU")
    insert_view(viewed_at: Time.utc(2026, 11, 1, 18), digest: "same", country: "AU", sample_rate: 1)
    insert_view(viewed_at: Time.utc(2026, 11, 2, 1), digest: "bot", bot: true, country: "")
    insert_view(viewed_at: Time.utc(2026, 11, 8, 12), digest: "nz", country: "NZ", sample_rate: 1)

    relation = RecordingStudioEmbeddable::EmbeddableViewLog.where(root_recording_id: @root_id)

    %w[day week month].each do |granularity|
      assert_equal legacy_period_counts(relation, granularity),
                   RecordingStudioEmbeddable::EmbeddableViewLog.counts_by_period(relation, granularity: granularity)
      assert_equal legacy_period_counts(relation, granularity, unique: true),
                   RecordingStudioEmbeddable::EmbeddableViewLog.counts_by_period(
                     relation, granularity: granularity, unique_viewers: true
                   )
    end

    assert_equal legacy_period_counts(relation.humans, "day"),
                 RecordingStudioEmbeddable::EmbeddableViewLog.counts_by_period(relation.humans, granularity: "day")
    assert_equal legacy_country_rows(relation),
                 RecordingStudioEmbeddable::EmbeddableViewLog.country_totals(relation)
  end

  test "counts follow the app time zone day" do
    Time.use_zone("America/New_York") do
      viewed_at = Time.utc(2026, 11, 2, 3)
      insert_view(viewed_at: viewed_at, digest: "east", root_id: @sampled_root_id)
      relation = RecordingStudioEmbeddable::EmbeddableViewLog.where(root_recording_id: @sampled_root_id)

      assert_equal({ Date.new(2026, 11, 1) => 1 },
                   RecordingStudioEmbeddable::EmbeddableViewLog.counts_by_period(relation, granularity: "day"))
    end
  end

  test "sampled rows scale view totals by one divided by the stored rate" do
    3.times do |index|
      insert_view(viewed_at: Time.utc(2026, 11, 3, 12), digest: "human-#{index}", sample_rate: 0.25,
                  root_id: @sampled_root_id, country: "FR")
    end
    insert_view(viewed_at: Time.utc(2026, 11, 3, 13), digest: "human-0", bot: true, sample_rate: 0.25,
                root_id: @sampled_root_id, country: "FR")
    insert_view(viewed_at: Time.utc(2026, 11, 4, 12), digest: "half", sample_rate: 0.5,
                root_id: @sampled_root_id, country: "FR")
    insert_view(viewed_at: Time.utc(2026, 11, 4, 13), digest: "full", sample_rate: 1,
                root_id: @sampled_root_id, country: "FR")

    relation = RecordingStudioEmbeddable::EmbeddableViewLog.where(root_recording_id: @sampled_root_id)
    counts = RecordingStudioEmbeddable::EmbeddableViewLog.counts_by_period(relation, granularity: "day")

    assert_equal 16, counts[Date.new(2026, 11, 3)]
    assert_equal 3, counts[Date.new(2026, 11, 4)]
    assert_equal 12, RecordingStudioEmbeddable::EmbeddableViewLog.counts_by_period(
      relation.humans, granularity: "day"
    )[Date.new(2026, 11, 3)]
    assert_equal 3, RecordingStudioEmbeddable::EmbeddableViewLog.counts_by_period(
      relation, granularity: "day", unique_viewers: true
    )[Date.new(2026, 11, 3)]

    france = RecordingStudioEmbeddable::EmbeddableViewLog.country_totals(relation).sole
    assert_equal(
      { country: "FR", views: 19, unique_views: 5, human_views: 15, bot_views: 4 },
      france
    )
  end

  private

  def insert_view(viewed_at:, digest:, bot: false, country: nil, sample_rate: nil, root_id: @root_id)
    metadata = {}
    metadata["country"] = country unless country.nil?
    metadata["sample_rate"] = sample_rate unless sample_rate.nil?
    RecordingStudioEmbeddable::EmbeddableViewLog.create!(
      root_recording_id: root_id,
      parent_recording_id: SecureRandom.uuid,
      status: "rendered",
      viewed_at: viewed_at,
      arrived_at: viewed_at,
      bot: bot,
      cache_hit: false,
      rate_limited: false,
      viewer_digest: digest,
      metadata: metadata
    )
  end

  def legacy_period_counts(relation, granularity, unique: false)
    rows = if unique
             relation.where.not(viewer_digest: nil).pluck(:viewed_at, :viewer_digest)
           else
             relation.pluck(:viewed_at).map { |viewed_at| [viewed_at, nil] }
           end
    rows.group_by { |viewed_at, _digest| legacy_bucket(viewed_at, granularity) }
        .transform_values do |bucket_rows|
          unique ? bucket_rows.map(&:last).uniq.size : bucket_rows.size
        end
  end

  def legacy_bucket(viewed_at, granularity)
    date = viewed_at.in_time_zone.to_date
    case granularity
    when "week" then date.beginning_of_week
    when "month" then date.beginning_of_month
    else date
    end
  end

  def legacy_country_rows(relation)
    geo = Hash.new { |hash, key| hash[key] = { views: 0, unique: {}, humans: 0, bots: 0 } }
    relation.pluck(:metadata, :viewer_digest, :bot).each do |metadata, digest, bot|
      country = metadata.is_a?(Hash) ? metadata["country"].presence : nil
      country ||= "Unknown"
      geo[country][:views] += 1
      geo[country][:unique][digest] = true if digest.present?
      if bot
        geo[country][:bots] += 1
      else
        geo[country][:humans] += 1
      end
    end
    geo.map do |country, data|
      {
        country: country,
        views: data[:views],
        unique_views: data[:unique].size,
        human_views: data[:humans],
        bot_views: data[:bots]
      }
    end.sort_by { |row| [-row[:views], row[:country]] }.first(15)
  end
end

class EmbedStatsScreenTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    RecordingStudioEmbeddable::EmbeddableViewLog.delete_all
    @user = User.create!(
      email: "stats-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    sign_in @user
    Current.actor = @user
    workspace = Workspace.create!(name: "Stats #{SecureRandom.hex(4)}")
    root = RecordingStudio.create_root_recording!(workspace, actor: @user)
    grant_embed_management!(actor: @user, recording: root)
    @page = root.record(Page, actor: @user) { |record| record.title = "Stats page" }
    @embed = @page.ensure_embed!(actor: @user, enabled: true)
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "stats screen shows scaled daily totals and country rows" do
    3.times do |index|
      insert_view(digest: "human-#{index}", bot: false)
    end
    insert_view(digest: "human-0", bot: true)

    get recording_studio_embeddable.stats_management_embed_path(
      @embed, range: "custom", from: "2026-11-03", to: "2026-11-03", granularity: "day"
    )

    assert_response :success
    assert_includes response.body, "&quot;data&quot;:[16]"
    rows = css_select("table.fp-table tbody tr").map { |tr| tr.css("td").map { |td| td.text.strip } }
    assert_equal ["FR", "16", "3", "12", "4"], rows.sole

    get recording_studio_embeddable.stats_management_embed_path(
      @embed, range: "custom", from: "2026-11-03", to: "2026-11-03", granularity: "day", viewer: "unique"
    )

    assert_response :success
    assert_includes response.body, "&quot;data&quot;:[3]"
  end

  private

  def insert_view(digest:, bot:)
    RecordingStudioEmbeddable::EmbeddableViewLog.create!(
      embed: @embed,
      root_recording_id: @page.root_recording_id.presence || @page.id,
      parent_recording_id: @page.id,
      status: "rendered",
      viewed_at: Time.utc(2026, 11, 3, 15),
      arrived_at: Time.utc(2026, 11, 3, 15),
      bot: bot,
      cache_hit: false,
      rate_limited: false,
      viewer_digest: digest,
      metadata: { "country" => "FR", "sample_rate" => 0.25 }
    )
  end
end
