# frozen_string_literal: true

namespace :recording_studio_embeddable do
  namespace :embed_css do
    desc "Build the self-contained embed stylesheet (Tailwind + FlatPack theme variables)"
    task build: :environment do
      path = RecordingStudioEmbeddable::EmbedStylesheet.build!
      digest = RecordingStudioEmbeddable::EmbedStylesheet.digest
      puts "Wrote #{path}"
      puts "Embed stylesheet digest #{digest}"
      puts "CDN embeds pick this up with bin/rails recording_studio_embeddable:republish_embeds"
    end
  end

  desc "Republish CDN embeds whose stored stylesheet digest is stale"
  task republish_embeds: :environment do
    count = RecordingStudioEmbeddable::EmbedStylesheet.republish_stale_embeds!
    puts "Enqueued #{count} embed republish #{'job'.pluralize(count)}."
  end
end
