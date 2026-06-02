class Article < ApplicationRecord
  recording_studio_recordable label: "Article", root: false, allowed_parent_types: [ "Workspace", "Folder" ]

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

  def self.recordable_type_label
    "Article"
  end

  class << self
    alias_method :recording_studio_type_label, :recordable_type_label
  end

  def recordable_name
    title.to_s.squish.presence || self.class.recordable_type_label
  end

  alias_method :recording_studio_label, :recordable_name
end
