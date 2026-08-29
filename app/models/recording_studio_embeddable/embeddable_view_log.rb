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
  end
end
