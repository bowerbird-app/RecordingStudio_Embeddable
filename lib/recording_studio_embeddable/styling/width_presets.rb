# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Styling
    module WidthPresets
      PRESETS = [
        { key: "full", label: "Full", value: "100%" },
        { key: "readable", label: "Readable", value: "40rem" },
        { key: "compact", label: "Compact", value: "24rem" }
      ].freeze

      CUSTOM_KEY = "custom"

      module_function

      def preset_for(width)
        normalized = width.to_s.strip
        normalized = "100%" if normalized.blank?

        match = PRESETS.find { |preset| preset[:value] == normalized }
        return match[:key] if match

        CUSTOM_KEY
      end

      def value_for(preset_key, custom_width: nil)
        key = preset_key.to_s
        preset = PRESETS.find { |entry| entry[:key] == key }
        return preset[:value] if preset

        custom = custom_width.to_s.strip
        custom.presence || "100%"
      end

      def custom?(width)
        preset_for(width) == CUSTOM_KEY
      end
    end
  end
end
