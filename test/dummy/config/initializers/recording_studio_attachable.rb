# frozen_string_literal: true

RecordingStudioAttachable.configure do |config|
  config.max_file_size = 25.megabytes
  config.image_processing_enabled = true
  config.image_processing_max_width = 2400
  config.image_processing_max_height = 2400
  config.image_processing_quality = 0.85

  # Public custom-domain host for DirectUrl. Development may override via
  # credentials dig(:recording_studio_attachable, :direct_url_host) when
  # credentials/development.yml.enc + development.key are present.
  # Default stays the dummy stand-in for CI / clones without the key.
  config.url_mode = :direct
  config.direct_url_host =
    DummyDevCredentials.dig(:recording_studio_attachable, :direct_url_host).presence ||
    "cdn.example.test"

  # Host-added custom variant. Leave preprocessed_variants unset so the default
  # (small/med/large + host-added names) includes :poster automatically.
  config.image_variants = {
    poster: { resize_to_limit: [1280, 720] }
  }
end
