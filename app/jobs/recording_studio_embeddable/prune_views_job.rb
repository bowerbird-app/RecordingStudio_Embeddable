# frozen_string_literal: true

module RecordingStudioEmbeddable
  # Hosts may keep scheduling this job. It deletes rows older than
  # prune_views_after (90 days by default). RecordingStudioLogs registers this
  # table with indefinite retention, so Logs cleanup does not prune it.
  class PruneViewsJob < ActiveJob::Base
    queue_as :default

    def perform(before: nil)
      Services::PruneEmbeddableViewLogs.call(before: before)
    end
  end
end
