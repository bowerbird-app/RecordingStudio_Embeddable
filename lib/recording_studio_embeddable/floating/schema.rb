# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Launcher settings stored on the embed. Unknown keys are rejected.
    # Popup URLs are never part of this document.
    class Schema
      POSITIONS = %w[bottom-left bottom-right].freeze
      KEYS = %w[position edge_spacing popup_width popup_height icon_url].freeze
      EDGE_SPACING_RANGE = (0..64)
      POPUP_WIDTH_RANGE = (280..440)
      POPUP_HEIGHT_RANGE = (360..720)
      DEFAULTS = {
        "position" => "bottom-right",
        "edge_spacing" => 20,
        "popup_width" => 380,
        "popup_height" => 560,
        "icon_url" => nil
      }.freeze

      Result = Struct.new(:settings, :errors, keyword_init: true) do
        def valid?
          errors.empty?
        end
      end

      def self.validate(value, recording = nil)
        new(value, recording: recording).validate
      end

      def self.with_defaults(value)
        result = validate(value)
        result.valid? ? result.settings : DEFAULTS.dup
      end

      def initialize(value, recording: nil)
        @value = value
        @recording = recording
      end

      def validate
        errors = []
        raw = normalize_hash
        return Result.new(settings: DEFAULTS.dup, errors: errors) if raw.nil?
        return Result.new(settings: {}, errors: ["must be an object"]) unless raw.is_a?(Hash)

        unknown = raw.keys.map(&:to_s) - KEYS
        errors << "includes unknown settings" if unknown.any?

        settings = DEFAULTS.dup
        if raw.key?("position") || raw.key?(:position)
          position = fetch(raw, "position").to_s
          if POSITIONS.include?(position)
            settings["position"] = position
          else
            errors << "position must be bottom-left or bottom-right"
          end
        end

        cast_range(raw, settings, errors, "edge_spacing", EDGE_SPACING_RANGE)
        cast_range(raw, settings, errors, "popup_width", POPUP_WIDTH_RANGE)
        cast_range(raw, settings, errors, "popup_height", POPUP_HEIGHT_RANGE)
        cast_icon(raw, settings, errors)

        Result.new(settings: errors.empty? ? settings : {}, errors: errors)
      end

      private

      attr_reader :value, :recording

      def normalize_hash
        return {} if value.nil?
        return value if value.is_a?(Hash)

        nil
      end

      def fetch(raw, key)
        raw.key?(key) ? raw[key] : raw[key.to_sym]
      end

      def present_key?(raw, key)
        raw.key?(key) || raw.key?(key.to_sym)
      end

      def cast_range(raw, settings, errors, key, range)
        return unless present_key?(raw, key)

        number = Integer(fetch(raw, key), exception: false)
        if number && range.cover?(number)
          settings[key] = number
        else
          errors << "#{key.tr('_', ' ')} must be between #{range.min} and #{range.max}"
        end
      end

      def cast_icon(raw, settings, errors)
        return unless present_key?(raw, "icon_url")

        icon = fetch(raw, "icon_url").to_s.strip
        if icon.blank?
          settings["icon_url"] = nil
          return
        end

        if IconUrl.allowed?(icon, recording: recording)
          settings["icon_url"] = icon
        else
          errors << "icon must be an allowlisted or attached image"
        end
      end
    end
  end
end
