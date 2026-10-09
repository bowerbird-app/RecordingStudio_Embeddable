# frozen_string_literal: true

require "test_helper"

class PublishedHtmlGuardTest < Minitest::Test
  def test_allows_direct_host_image_urls
    html = <<~HTML
      <img src="https://cdn.example.test/abc123" srcset="https://cdn.example.test/v-small 480w">
    HTML

    assert RecordingStudioEmbeddable::PublishedHtmlGuard.direct_only?(html)
    assert_equal html, RecordingStudioEmbeddable::PublishedHtmlGuard.assert_direct_only!(html)
  end

  def test_rejects_active_storage_paths
    html = '<img src="/rails/active_storage/blobs/redirect/xyz">'

    refute RecordingStudioEmbeddable::PublishedHtmlGuard.direct_only?(html)
    error = assert_raises(ArgumentError) do
      RecordingStudioEmbeddable::PublishedHtmlGuard.assert_direct_only!(html)
    end
    assert_match(%r{must not include Rails/Active Storage}, error.message)
  end

  def test_rejects_attachable_preview_fallback_paths
    html = '<img src="/recording_studio_attachable/attachments/1/preview/med">'

    refute RecordingStudioEmbeddable::PublishedHtmlGuard.direct_only?(html)
  end
end
