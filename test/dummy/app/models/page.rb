begin
  require "recording_studio_publishable"
rescue LoadError
  nil
end

class Page < ApplicationRecord
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
    renderer: "pages/show",
    require_publishable: defined?(RecordingStudioPublishable)
  )
end