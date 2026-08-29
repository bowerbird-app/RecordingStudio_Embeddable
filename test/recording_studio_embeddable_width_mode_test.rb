# frozen_string_literal: true

require "test_helper"

class RecordingStudioEmbeddableWidthModeTest < ActiveSupport::TestCase
  WidthMode = RecordingStudioEmbeddable::Styling::WidthMode

  def test_mode_for_maps_auto_and_custom
    assert_equal "auto", WidthMode.mode_for("100%")
    assert_equal "auto", WidthMode.mode_for("")
    assert_equal "auto", WidthMode.mode_for(nil)
    assert_equal "custom", WidthMode.mode_for("720px")
    assert_equal "custom", WidthMode.mode_for("40rem")
    assert_equal "custom", WidthMode.mode_for("24rem")
  end

  def test_value_for_returns_css_widths
    assert_equal "100%", WidthMode.value_for("auto")
    assert_equal "720px", WidthMode.value_for("custom", custom_width: "720px")
    assert_equal "100%", WidthMode.value_for("custom", custom_width: "")
  end

  def test_auto_and_custom_predicates
    assert WidthMode.auto?("100%")
    refute WidthMode.auto?("720px")
    assert WidthMode.custom?("720px")
    refute WidthMode.custom?("100%")
  end
end
