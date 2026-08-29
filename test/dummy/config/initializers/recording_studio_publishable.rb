# frozen_string_literal: true

RecordingStudioPublishable.configure do |config|
  config.layout = "recording_studio/default_layout"

  config.management_close_url_resolver = lambda do |controller:, recording: nil, **|
    _ = recording
    controller&.main_app&.root_path || "/"
  end
end
