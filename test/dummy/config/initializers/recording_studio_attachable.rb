# frozen_string_literal: true

RecordingStudioAttachable.configure do |config|
  config.max_file_size = 25.megabytes
  config.image_processing_enabled = true
  config.image_processing_max_width = 2400
  config.image_processing_max_height = 2400
  config.image_processing_quality = 0.85

  # Dummy-only public host for Attachable direct URLs (no real R2 credentials).
  # Screenshots use a local DummyCdnController that serves blob keys for this host.
  config.url_mode = :direct
  config.direct_url_host = ENV.fetch("ATTACHABLE_DIRECT_URL_HOST", "cdn.example.test")

  # Host-added custom variant. Leave preprocessed_variants unset so the default
  # (small/med/large + host-added names) includes :poster automatically.
  config.image_variants = {
    poster: { resize_to_limit: [1280, 720] }
  }
end
