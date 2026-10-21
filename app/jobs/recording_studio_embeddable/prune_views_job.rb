# frozen_string_literal: true

module RecordingStudioEmbeddable
  # Hosts may keep scheduling this job. With logs_summaries_enabled false it
  # still deletes rows older than prune_views_after. With the flag true it
  # delegates to RecordingStudioLogs retention (a UTC day needs a covering
  # summary success before raw rows for that day are removed).
  class PruneViewsJob < ActiveJob::Base
    queue_as :default

    def perform(before: nil)
      Services::PruneEmbeddableViewLogs.call(before: before)
    end
  end
end
