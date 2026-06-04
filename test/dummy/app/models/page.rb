begin
  require "recording_studio_publishable"
rescue LoadError
  nil
end

class Page < ApplicationRecord
  recording_studio_recordable label: "Page", root: false, allowed_parent_types: [ "Workspace", "Folder" ]

  if defined?(RecordingStudioPublishable::ParentRecordable)
    include RecordingStudioPublishable::ParentRecordable

    recording_studio_publishable(
      public_controller: "pages",
      public_action: :show,
      schedule: true,
      seo: false
    )
  end

  include RecordingStudio::Capabilities::Embeddable.to(
    embed_controller: "pages",
    embed_action: :embed,
    require_publishable: defined?(RecordingStudioPublishable)
  )

  def self.recordable_type_label
    "Page"
  end

  class << self
    alias_method :recording_studio_type_label, :recordable_type_label
  end

  def recordable_name
    title.to_s.squish.presence || self.class.recordable_type_label
  end

  alias_method :recording_studio_label, :recordable_name
end
