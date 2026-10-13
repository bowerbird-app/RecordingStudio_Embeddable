# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Floating
    # Launcher icons may only be Attachable direct URLs for the parent
    # recording, or https/http URLs on hosts the app listed in
    # config.floating_icon_hosts.
    class IconUrl
      MAX_LENGTH = 2000

      def self.allowed?(url, recording: nil)
        new(url, recording: recording).allowed?
      end

      def initialize(url, recording: nil)
        @url = url.to_s.strip
        @recording = recording
      end

      def allowed?
        return true if url.blank?
        return false if url.length > MAX_LENGTH
        return false unless https_url?

        allowlisted_host? || attachable_url?
      end

      private

      attr_reader :url, :recording

      def https_url?
        uri.is_a?(URI::HTTP) && %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.blank?
      rescue URI::InvalidURIError
        false
      end

      def uri
        @uri ||= URI.parse(url)
      end

      def allowlisted_host?
        host = uri.host.to_s.downcase
        hosts = Array(RecordingStudioEmbeddable.configuration.floating_icon_hosts).filter_map do |entry|
          host_only(entry)
        end
        hosts.include?(host)
      end

      def host_only(entry)
        value = entry.to_s.strip
        return if value.blank?

        parsed = value.include?("://") ? URI.parse(value) : URI.parse("https://#{value}")
        parsed.host.to_s.downcase.presence
      rescue URI::InvalidURIError
        nil
      end

      def attachable_url?
        attachable_urls.any? { |candidate| candidate == url }
      end

      def attachable_urls
        return [] unless recording.respond_to?(:images)

        Array(recording.images).flat_map { |attachment| urls_for(attachment) }
      rescue StandardError
        []
      end

      def urls_for(attachment)
        urls = []
        urls << attachment.original_url(mode: :direct) if attachment.respond_to?(:original_url)
        return urls unless attachment.respond_to?(:url_for_variant) && attachment.respond_to?(:variant_processed?)

        %i[small med large poster].each do |name|
          next unless attachment.variant_processed?(name)

          urls << attachment.url_for_variant(name, mode: :direct)
        rescue ArgumentError
          nil
        end
        urls.compact
      end
    end
  end
end
