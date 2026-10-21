# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Services
    class PruneEmbeddableViewLogs
      class << self
        def call(before: nil)
          cutoff = before.presence || default_before
          return 0 if cutoff.blank?
          return GuardedEmbeddableViewLogRetention.call(before: cutoff) if LogsRegistration.summaries_enabled?
          return 0 unless EmbeddableViewLog.table_exists?

          EmbeddableViewLog.where(EmbeddableViewLog.arel_table[:viewed_at].lt(cutoff)).delete_all
        end

        private

        def default_before
          duration = RecordingStudioEmbeddable.configuration.prune_views_after
          duration ? Time.current - duration : nil
        end
      end
    end
  end
end
