class Article < ApplicationRecord
  include RecordingStudio::Capabilities::Embeddable.to(
    embed_controller: "articles",
    embed_action: :show,
    cache: { max_age: 600, stale_while_revalidate: 120 },
    require_publishable: true
  )

  # Uncomment this block if you want Article to use RecordingStudioPublishable.
  if defined?(RecordingStudioPublishable::ParentRecordable)
    include RecordingStudioPublishable::ParentRecordable
  
    recording_studio_publishable(
      public_controller: "articles",
      public_action: :show,
      schedule: true,
      seo: false
    )
  end
end
