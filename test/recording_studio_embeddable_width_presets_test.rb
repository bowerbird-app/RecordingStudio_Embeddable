# frozen_string_literal: true

require "test_helper"

class RecordingStudioEmbeddableWidthPresetsTest < ActiveSupport::TestCase
  WidthPresets = RecordingStudioEmbeddable::Styling::WidthPresets

  def test_preset_for_maps_known_widths
    assert_equal "full", WidthPresets.preset_for("100%")
    assert_equal "readable", WidthPresets.preset_for("40rem")
    assert_equal "compact", WidthPresets.preset_for("24rem")
    assert_equal "custom", WidthPresets.preset_for("720px")
    assert_equal "full", WidthPresets.preset_for("")
    assert_equal "full", WidthPresets.preset_for(nil)
  end

  def test_value_for_returns_css_widths
    assert_equal "100%", WidthPresets.value_for("full")
    assert_equal "40rem", WidthPresets.value_for("readable")
    assert_equal "24rem", WidthPresets.value_for("compact")
    assert_equal "720px", WidthPresets.value_for("custom", custom_width: "720px")
    assert_equal "100%", WidthPresets.value_for("custom", custom_width: "")
  end

  def test_custom_predicate
    assert WidthPresets.custom?("720px")
    refute WidthPresets.custom?("100%")
  end
end
