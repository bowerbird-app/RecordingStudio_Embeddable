# frozen_string_literal: true

namespace :recording_studio_embeddable do
  namespace :view_logs do
    desc "Rebuild Logs daily embed-view summaries for FROM..TO (inclusive UTC days)"
    task backfill_summaries: :environment do
      from = Date.iso8601(ENV.fetch("FROM"))
      to = Date.iso8601(ENV.fetch("TO"))
      RecordingStudioEmbeddable::Services::RebuildEmbeddableViewLogSummaries.backfill!(from: from, to: to)
      puts "Rebuilt embed view summaries from #{from} to #{to}"
    end
  end
end
