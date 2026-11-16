# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User", "RecordingStudioApi::ApiClient" ]
  # Mounted pages call admin? against this root. Without it, Accessible 0.45 denies.
  config.admin_root_resolver = lambda {
    workspace = Workspace.find_by(name: "Studio Workspace")
    workspace && RecordingStudio.root_recording_for(workspace)
  }
end
