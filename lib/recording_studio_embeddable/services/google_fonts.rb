# frozen_string_literal: true

require "json"
require "net/http"

module RecordingStudioEmbeddable
  module Services
    class GoogleFonts
      CACHE_KEY = "recording_studio_embeddable/google_fonts/families/v2"
      LEGACY_FONT_KEYS = RecordingStudioEmbeddable::Styling::Tokens::FONT_STACKS.keys.map(&:downcase).freeze

      class << self
        def options
          fonts = if api_key.blank?
                    fallback_options
                  else
                    cache_store.fetch(CACHE_KEY, expires_in: 12.hours) { fetch_families }
                  end

          normalize_options(fonts)
        rescue StandardError
          fallback_options
        end

        private

        def fetch_families
          response = perform_request
          parsed = JSON.parse(response.body)
          families = Array(parsed["items"]).filter_map do |item|
            family = item["family"].to_s.strip
            family if family.present?
          end
          families
        rescue JSON::ParserError
          fallback_options
        end

        def perform_request
          uri = URI("https://www.googleapis.com/webfonts/v1/webfonts")
          uri.query = URI.encode_www_form(key: api_key, sort: "popularity")

          Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 5, open_timeout: 5) do |http|
            request = Net::HTTP::Get.new(uri)
            response = http.request(request)
            return response if response.is_a?(Net::HTTPSuccess)

            raise "Google Fonts API request failed with status #{response.code}"
          end
        end

        def fallback_options
          []
        end

        def normalize_options(fonts)
          Array(fonts)
            .map(&:to_s)
            .map(&:strip)
            .reject(&:blank?)
            .reject { |font| LEGACY_FONT_KEYS.include?(font.downcase) }
            .uniq
        end

        def api_key
          ENV["GOOGLE_FONTS_API_KEY"].to_s
        end

        def cache_store
          return Rails.cache if defined?(Rails) && Rails.respond_to?(:cache)

          @cache_store ||= ActiveSupport::Cache::MemoryStore.new
        end
      end
    end
  end
end