# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Parses a browser Origin or Referer into a scheme/host/port origin.
    # Returns nil for missing, wildcard, or non-http(s) values.
    class Origin
      def self.parse(value)
        raw = value.to_s
        return if raw.blank? || raw == "*"
        return if raw.match?(/[\s\r\n]/)

        uri = URI.parse(raw)
        return unless uri.is_a?(URI::HTTP) && uri.host.present?
        return unless %w[http https].include?(uri.scheme)

        host = uri.host.downcase
        default_port = uri.scheme == "https" ? 443 : 80
        authority = uri.port == default_port ? host : "#{host}:#{uri.port}"
        "#{uri.scheme}://#{authority}"
      rescue URI::InvalidURIError
        nil
      end

      # Echo the request Origin only when it parses and matches its normalized form.
      # Browsers require the reflected value to match the request header.
      def self.echoable(value)
        raw = value.to_s
        normalized = parse(raw)
        return if normalized.nil?
        return if raw != normalized

        raw
      end
    end
  end
end
