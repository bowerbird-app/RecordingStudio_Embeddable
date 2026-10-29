# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # HTML iframe sandbox tokens and permissions-policy features.
    # Sandbox: https://html.spec.whatwg.org/multipage/iframe-embed-object.html#attr-iframe-sandbox
    module PopupFrameTokens
      SANDBOX_TOKENS = %w[
        allow-downloads
        allow-forms
        allow-modals
        allow-orientation-lock
        allow-pointer-lock
        allow-popups
        allow-popups-to-escape-sandbox
        allow-presentation
        allow-same-origin
        allow-scripts
        allow-storage-access-by-user-activation
        allow-top-navigation
        allow-top-navigation-by-user-activation
        allow-top-navigation-to-custom-protocols
      ].freeze

      ALLOW_FEATURES = %w[
        accelerometer
        ambient-light-sensor
        attribution-reporting
        autoplay
        bluetooth
        browsing-topics
        camera
        captured-surface-control
        clipboard-read
        clipboard-write
        compute-pressure
        cross-origin-isolated
        display-capture
        encrypted-media
        fullscreen
        gamepad
        geolocation
        gyroscope
        hid
        identity-credentials-get
        idle-detection
        local-fonts
        magnetometer
        microphone
        midi
        otp-credentials
        payment
        picture-in-picture
        publickey-credentials-create
        publickey-credentials-get
        screen-wake-lock
        serial
        speaker-selection
        storage-access
        usb
        web-share
        window-management
        xr-spatial-tracking
      ].freeze
    end
  end
end
