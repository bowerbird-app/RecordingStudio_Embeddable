# frozen_string_literal: true

module RecordingStudioEmbeddable
  # Rejects Artifacts HTML that still points at Rails / Active Storage delivery.
  module PublishedHtmlGuard
    FORBIDDEN_PATH_PATTERN = %r{
      /rails/active_storage
      | /recording_studio_attachable/[^"' \s>]*/preview/
      | /recording_studio_attachable/[^"' \s>]*/file
    }ix

    module_function

    def assert_direct_only!(html)
      return html if html.blank?

      match = html.to_s.match(FORBIDDEN_PATH_PATTERN)
      return html if match.nil?

      raise ArgumentError,
            "Published embed HTML must not include Rails/Active Storage image paths " \
            "(found #{match[0].inspect}). Process Attachable variants before publish."
    end

    def direct_only?(html)
      assert_direct_only!(html)
      true
    rescue ArgumentError
      false
    end
  end
end
