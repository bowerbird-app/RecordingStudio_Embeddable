# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Styling
    module WidthMode
      AUTO = "auto"
      CUSTOM = "custom"
      AUTO_VALUE = "100%"

      module_function

      def mode_for(width)
        normalized = width.to_s.strip
        return AUTO if normalized.blank? || normalized == AUTO_VALUE

        CUSTOM
      end

      def value_for(mode, custom_width: nil)
        return AUTO_VALUE unless mode.to_s == CUSTOM

        custom_width.to_s.strip.presence || AUTO_VALUE
      end

      def auto?(width)
        mode_for(width) == AUTO
      end

      def custom?(width)
        mode_for(width) == CUSTOM
      end
    end
  end
end
