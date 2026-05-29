# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Services
    class NormalizePayload
      def self.call(request)
        {
          ip: request.remote_ip.to_s,
          user_agent: request.user_agent.to_s[0, 512],
          referer: request.referer.to_s[0, 1024],
          origin: request.get_header("HTTP_ORIGIN").to_s[0, 1024],
          request_host: request.host.to_s[0, 255],
          request_path: redacted_path(request),
          request_method: request.request_method.to_s[0, 16],
          viewed_at: current_time
        }
      end

      def self.redacted_path(request)
        path = request.path.to_s
        path = path.sub(%r{(/embeds/)[^/?]+}, "\\1[token]")
        path[0, 2048]
      end

      def self.current_time
        Time.respond_to?(:current) ? Time.current : Time.now
      end
    end
  end
end
