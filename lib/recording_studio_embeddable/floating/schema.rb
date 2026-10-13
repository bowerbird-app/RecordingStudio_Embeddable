# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Position stored on the embed. Spacing, panel size, and the icon are
    # host configuration (see HostSettings) and are rejected here.
    class Schema
      POSITIONS = %w[bottom-left bottom-right].freeze
      KEYS = %w[position].freeze
      DEFAULTS = {
        "position" => "bottom-right"
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
        # Callers still pass the parent recording. Position does not read it.
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
    end
  end
end
