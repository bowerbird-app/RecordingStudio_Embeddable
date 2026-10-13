# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Edge spacing, panel size, the icon, and the management label are chosen
    # by the host app. Capability +floating_options+ override
    # +config.floating_defaults+. Invalid values fall back to the previous
    # layer. They are never stored on the embed.
    class HostSettings
      EDGE_SPACING_RANGE = (0..64)
      POPUP_WIDTH_RANGE = (280..440)
      POPUP_HEIGHT_RANGE = (360..720)
      LABEL_MAX = 40
      # Mirrors the launcher button, the gap above it, and a little room for
      # the shadow in widget.js. The preview frame is this tall so the open
      # popup stays inside it at the host size.
      PREVIEW_LAUNCHER_SIZE = 56
      PREVIEW_POPUP_GAP = 12
      PREVIEW_SHADOW = 16
      RANGES = {
        "edge_spacing" => EDGE_SPACING_RANGE,
        "popup_width" => POPUP_WIDTH_RANGE,
        "popup_height" => POPUP_HEIGHT_RANGE
      }.freeze
      BUILTIN = {
        "edge_spacing" => 20,
        "popup_width" => 380,
        "popup_height" => 560,
        "icon_url" => nil,
        "label" => "Floating button"
      }.freeze

      def self.for(recording)
        new(recording).to_h
      end

      def self.preview_frame_height(recording)
        host = self.for(recording)
        host["popup_height"] + PREVIEW_LAUNCHER_SIZE + PREVIEW_POPUP_GAP +
          (host["edge_spacing"] * 2) + PREVIEW_SHADOW
      end

      def initialize(recording)
        @recording = recording
      end

      def to_h
        resolved = BUILTIN.dup
        apply(resolved, RecordingStudioEmbeddable.configuration.floating_defaults)
        apply(resolved, capability_options)
        resolved
      end

      private

      attr_reader :recording

      def capability_options
        return {} if recording.nil?

        options = Renderer.options_for(recording)
        options[:floating_options] || options["floating_options"] || {}
      end

      def apply(resolved, raw)
        return unless raw.is_a?(Hash)

        RANGES.each do |key, range|
          number = cast_number(raw, key, range)
          resolved[key] = number unless number.nil?
        end

        icon = cast_icon(raw)
        resolved["icon_url"] = icon unless icon == :skip

        label = cast_label(raw)
        resolved["label"] = label unless label == :skip
      end

      def cast_number(raw, key, range)
        return unless present?(raw, key)

        number = Integer(fetch(raw, key), exception: false)
        number if number && range.cover?(number)
      end

      def cast_icon(raw)
        return :skip unless present?(raw, "icon_url")

        icon = fetch(raw, "icon_url").to_s.strip
        return nil if icon.blank?
        return icon if IconUrl.allowed?(icon, recording: recording)

        :skip
      end

      def cast_label(raw)
        return :skip unless present?(raw, "label")

        value = fetch(raw, "label")
        return :skip unless value.is_a?(String) || value.is_a?(Symbol)

        label = value.to_s.squish
        return :skip if label.blank? || label.length > LABEL_MAX

        label
      end

      def present?(raw, key)
        raw.key?(key) || raw.key?(key.to_sym)
      end

      def fetch(raw, key)
        raw.key?(key) ? raw[key] : raw[key.to_sym]
      end
    end
  end
end
