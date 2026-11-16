# frozen_string_literal: true

module RecordingStudioEmbeddable
  class EmbeddableViewLog < ApplicationRecord
    self.table_name = "recording_studio_embeddable_view_logs"

    belongs_to :embed, class_name: "RecordingStudioEmbeddable::Embed", optional: true, inverse_of: :embeddable_view_logs

    scope :recent, -> { order(viewed_at: :desc, created_at: :desc) }
    scope :humans, -> { where(bot: false) }
    scope :bots, -> { where(bot: true) }
    scope :for_parent_recording, lambda { |recording|
      where(parent_recording_id: recording.respond_to?(:id) ? recording.id : recording)
    }
    scope :with_status, ->(status) { where(status: status) }
    scope :since, ->(time) { where(arel_table[:viewed_at].gteq(time)) }
    scope :until_time, ->(time) { where(arel_table[:viewed_at].lteq(time)) }
    scope :for_token, ->(token) { joins(:embed).where(recording_studio_embeddable_embeds: { token: token }) }
    scope :unique_visitors, -> { select(:embed_id, :viewer_digest).distinct }

    STATUSES = %w[
      rendered not_modified not_found forbidden disabled unpublished rate_limited invalid_token
      oembed_rendered oembed_blocked error
    ].freeze

    validates :status, inclusion: { in: STATUSES }

    def self.summary_for(embed)
      relation = where(embed: embed)
      {
        total: relation.count,
        humans: relation.humans.count,
        bots: relation.bots.count,
        unique_visitors: relation.distinct.count(:viewer_digest),
        statuses: relation.group(:status).count,
        referer_hosts: relation.where.not(referer_host: nil).group(:referer_host).count
      }
    end

    # View totals are sum(1 / sample_rate), which is the row count when every
    # row was logged (rate 1, or no rate stored). Unique viewers stay a distinct
    # count of logged digests. Buckets follow the app time zone, matching the
    # previous per-row date grouping.
    def self.counts_by_period(relation, granularity:, unique_viewers: false)
      period = period_sql(granularity)
      scope = unique_viewers ? relation.where.not(viewer_digest: nil) : relation
      value_sql = unique_viewers ? "COUNT(DISTINCT viewer_digest)" : "ROUND(SUM(#{sample_weight_sql}))"
      scope.group(Arel.sql(period)).pluck(Arel.sql(period), Arel.sql(value_sql)).each_with_object({}) do |row, counts|
        bucket, count = row
        counts[bucket.to_date] = count.to_i
      end
    end

    def self.country_totals(relation, limit: 15)
      country = country_sql
      weight = sample_weight_sql
      relation.group(Arel.sql(country)).order(Arel.sql("2 DESC, 1 ASC")).limit(limit).pluck(
        Arel.sql(country),
        Arel.sql("ROUND(COALESCE(SUM(#{weight}), 0))"),
        Arel.sql("COUNT(DISTINCT viewer_digest)"),
        Arel.sql("ROUND(COALESCE(SUM(#{weight}) FILTER (WHERE bot = FALSE), 0))"),
        Arel.sql("ROUND(COALESCE(SUM(#{weight}) FILTER (WHERE bot = TRUE), 0))")
      ).map do |name, views, unique_views, human_views, bot_views|
        {
          country: name,
          views: views.to_i,
          unique_views: unique_views.to_i,
          human_views: human_views.to_i,
          bot_views: bot_views.to_i
        }
      end
    end

    PERIOD_UNITS = { "day" => "day", "week" => "week", "month" => "month" }.freeze

    def self.period_sql(granularity)
      unit = PERIOD_UNITS.fetch(granularity.to_s, "day")
      zone = Time.zone&.tzinfo&.name || "UTC"
      viewed_at = "viewed_at AT TIME ZONE 'UTC' AT TIME ZONE #{connection.quote(zone)}"
      "date_trunc(#{connection.quote(unit)}, #{viewed_at})::date"
    end

    def self.country_sql
      "COALESCE(NULLIF(metadata->>'country', ''), 'Unknown')"
    end

    # Missing or zero rates count as one logged view, not an inflated estimate.
    def self.sample_weight_sql
      "1.0 / COALESCE(NULLIF((metadata->>'sample_rate')::numeric, 0), 1)"
    end

    private_class_method :period_sql, :country_sql, :sample_weight_sql
  end
end
