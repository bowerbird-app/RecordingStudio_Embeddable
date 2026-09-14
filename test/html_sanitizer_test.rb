# frozen_string_literal: true

require "test_helper"

class HtmlSanitizerTest < Minitest::Test
  def test_strips_script_elements
    html = '<p>safe</p><script>alert(1)</script><div onclick="x()">ok</div>'

    cleaned = RecordingStudioEmbeddable::HtmlSanitizer.call(html)

    refute_includes cleaned, "<script"
    refute_includes cleaned, "alert(1)"
    assert_includes cleaned, "<p>safe</p>"
  end

  def test_strips_iframe_object_embed_link_meta
    html = <<~HTML
      <p>body</p>
      <iframe src="https://evil.test"></iframe>
      <object data="x"></object>
      <embed src="x">
      <link rel="stylesheet" href="https://evil.test/x.css">
      <meta http-equiv="refresh" content="0;url=https://evil.test">
    HTML

    cleaned = RecordingStudioEmbeddable::HtmlSanitizer.call(html)

    refute_match(/<(iframe|object|embed|link|meta)\b/i, cleaned)
    assert_includes cleaned, "<p>body</p>"
  end

  def test_strips_on_event_attributes
    html = '<a href="/ok" onclick="evil()" onmouseover="evil()">link</a>'

    cleaned = RecordingStudioEmbeddable::HtmlSanitizer.call(html)

    refute_includes cleaned, "onclick"
    refute_includes cleaned, "onmouseover"
    assert_includes cleaned, 'href="/ok"'
  end

  def test_strips_javascript_href_and_src
    html = '<a href="javascript:alert(1)">x</a><img src="javascript:alert(2)">'

    cleaned = RecordingStudioEmbeddable::HtmlSanitizer.call(html)

    refute_match(/javascript:/i, cleaned)
    assert_includes cleaned, "<a>x</a>"
  end

  def test_keeps_safe_markup_and_style_attributes
    html = '<article class="card" style="color:#111"><strong>Hi</strong></article>'

    cleaned = RecordingStudioEmbeddable::HtmlSanitizer.call(html)

    assert_equal html, cleaned
  end
end
