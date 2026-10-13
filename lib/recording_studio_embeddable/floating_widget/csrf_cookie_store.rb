# frozen_string_literal: true

module RecordingStudioEmbeddable
  module FloatingWidget
    # CSRF token for a cross-site iframe. Stays off the host session cookie.
    class CsrfCookieStore
      COOKIE = "recording_studio_embeddable_widget_csrf"

      def fetch(request)
        request.cookie_jar.encrypted[COOKIE]
      end

      def store(request, csrf_token)
        request.cookie_jar.encrypted[COOKIE] = cookie_options(request).merge(value: csrf_token)
      end

      def reset(request)
        request.cookie_jar.delete(COOKIE, cookie_options(request))
      end

      private

      def cookie_options(request)
        {
          httponly: true,
          secure: true,
          same_site: :none,
          partitioned: true,
          path: request.path
        }
      end
    end
  end
end
