# frozen_string_literal: true

module RecordingStudioEmbeddable
  # Hosts may keep scheduling this job. It deletes rows older than
  # prune_views_after (90 days by default). RecordingStudioLogs registers this
  # table with indefinite retention, so Logs cleanup does not prune it.
  class PruneViewsJob < ActiveJob::Base
    queue_as :default

    def perform(before: nil)
      cutoff = before || default_cutoff
      return unless cutoff

      EmbeddableViewLog.where(EmbeddableViewLog.arel_table[:viewed_at].lt(cutoff)).delete_all
    end

    private

    def default_cutoff
      duration = RecordingStudioEmbeddable.configuration.prune_views_after
      duration ? Time.current - duration : nil
    end
  end
end
