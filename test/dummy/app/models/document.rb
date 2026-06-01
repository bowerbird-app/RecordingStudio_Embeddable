begin
  require "recording_studio_publishable"
rescue LoadError
  nil
end

class Document < ApplicationRecord
  if defined?(RecordingStudioPublishable::ParentRecordable)
    include RecordingStudioPublishable::ParentRecordable

    recording_studio_publishable(
      public_controller: "documents",
      public_action: :show,
      schedule: true,
      seo: false
    )
  end
end
