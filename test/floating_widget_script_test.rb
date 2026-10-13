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
    refute_match(/postMessage\(\s*[^,\n]+,\s*["']\*["']\s*\)/, source)
    refute_includes source, "from \"react\""
    refute_includes source, "from 'react'"
  end
end
