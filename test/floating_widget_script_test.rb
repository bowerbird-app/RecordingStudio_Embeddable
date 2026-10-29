# frozen_string_literal: true

require "test_helper"

class FloatingWidgetScriptTest < ActiveSupport::TestCase
  def source
    File.read(File.expand_path("../lib/recording_studio_embeddable/floating/widget.js", __dir__))
  end

  test "classic script reads data-embed and never posts to a star origin" do
    assert_includes source, "currentScript"
    assert_includes source, "data-embed"
    assert_includes source, "data-config"
    assert_includes source, "data-preview-open"
    assert_includes source, 'widget.setAttribute("data-preview", "true")'
    assert_includes source, "openWidget(widget, frame, popupUrl.href, launcher)"
    assert_equal 1, source.scan('frame.setAttribute("sandbox", "allow-scripts allow-forms allow-same-origin")').size
    assert_includes source, 'typeof config.sandbox === "string"'
    assert_includes source, 'typeof config.allow === "string" && config.allow'
    refute_includes source, "clipboard-write"
    refute_match(/postMessage\(\s*[^,\n]+,\s*["']\*["']\s*\)/, source)
    refute_includes source, "from \"react\""
    refute_includes source, "from 'react'"
  end
end
