# frozen_string_literal: true

# Accessible gate for Admin mounts. Prefer the switched AdminRoot; fall back to
# the seeded "Admin" root recording (same pattern as RecordingStudio_api dummy).
RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.access_recording_resolver = lambda do |context|
    if context.controller.respond_to?(:current_root_recording, true)
      current_root = context.controller.send(:current_root_recording)
      next current_root if current_root.present?
    end

    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio::Recording.unscoped.find_by(recordable: admin_root, trashed_at: nil)
  end
  config.site_admin_recording_resolver = config.access_recording_resolver
end
