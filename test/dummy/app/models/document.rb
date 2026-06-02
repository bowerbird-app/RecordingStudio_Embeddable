begin
  require "recording_studio_publishable"
rescue LoadError
  nil
end

class Document < ApplicationRecord
  recording_studio_recordable label: "Document", root: false, allowed_parent_types: [ "Workspace", "Folder" ]

  if defined?(RecordingStudioPublishable::ParentRecordable)
    include RecordingStudioPublishable::ParentRecordable

    recording_studio_publishable(
      public_controller: "documents",
      public_action: :show,
      schedule: true,
      seo: false
    )
  end

  def self.recordable_type_label
    "Document"
  end

  class << self
    alias_method :recording_studio_type_label, :recordable_type_label
  end

  def recordable_name
    title.to_s.squish.presence || self.class.recordable_type_label
  end

  alias_method :recording_studio_label, :recordable_name
end
