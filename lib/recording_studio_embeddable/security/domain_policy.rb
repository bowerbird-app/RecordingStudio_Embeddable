# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Security
    class DomainPolicy
      DOMAIN_PATTERN = /\A(\*\.)?[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+\z/i

      def self.valid_domain?(domain)
        value = domain.to_s.downcase.strip
        return false unless value.match?(DOMAIN_PATTERN)
        return false if value == "*" || value.match?(/\A\*?\.[a-z]+\z/)
        return false if value.include?("localhost") || value.match?(/\A(?:\d{1,3}\.){3}\d{1,3}\z/)

        true
      end

      def initialize(embed:, origin: nil, referer: nil, options: {})
        @embed = embed
        @origin = origin
        @referer = referer
        @options = options || {}
      end

      def allowed?
        return false unless embeddable_available?
        return true if host.blank?
        return false if matches_any?(host, blocked_domains)
        return true if RecordingStudioEmbeddable.configuration.allow_any_domain && allowed_domains.empty?
        return true if allowed_domains.empty?

        matches_any?(host, allowed_domains)
      end

      def frame_ancestors
        domains = allowed_domains
        return ["'none'"] unless embeddable_available?
        return ["*"] if domains.empty? && RecordingStudioEmbeddable.configuration.allow_any_domain

        ["'self'"] + domains.flat_map { |domain| csp_sources_for(domain) }.uniq
      end

      private

      attr_reader :embed, :origin, :referer, :options

      def host
        @host ||= begin
          value = origin.presence || referer
          value.present? ? URI.parse(value).host.to_s.downcase : nil
        rescue URI::InvalidURIError
          nil
        end
      end

      def allowed_domains
        domains = []
        if inherit_global_domains?
          domains.concat(normalize_domains(RecordingStudioEmbeddable.configuration.allowed_embedder_domains))
        end
        domains.concat(normalize_domains(options[:allowed_embedder_domains])) if inherit_capability_domains?
        domains.concat(normalize_domains(embed.allowed_domains))
        domains.uniq
      end

      def blocked_domains
        domains = []
        if inherit_global_domains?
          domains.concat(normalize_domains(RecordingStudioEmbeddable.configuration.blocked_embedder_domains))
        end
        domains.concat(normalize_domains(options[:blocked_embedder_domains])) if inherit_capability_domains?
        domains.concat(normalize_domains(embed.blocked_domains))
        domains.uniq
      end

      def embeddable_available?
        return true if RecordingStudioEmbeddable.configuration.allow_any_domain
        return true if allowed_domains.any?

        !RecordingStudioEmbeddable.configuration.require_domain_allowlist
      end

      def inherit_capability_domains?
        !embed.respond_to?(:inherit_capability_domains) || embed.inherit_capability_domains
      end

      def inherit_global_domains?
        !embed.respond_to?(:inherit_global_domains) || embed.inherit_global_domains
      end

      def csp_sources_for(domain)
        return ["https://#{domain.delete_prefix('*.')}", "https://#{domain}"] if domain.start_with?("*.")

        ["https://#{domain}"]
      end

      def normalize_domains(domains)
        Array(domains).map { |domain| domain.to_s.downcase.strip }.select { |domain| self.class.valid_domain?(domain) }
      end

      def matches_any?(host, domains)
        domains.any? do |domain|
          if domain.start_with?("*.")
            host == domain.delete_prefix("*.") || host.end_with?(".#{domain.delete_prefix('*.')}")
          else
            host == domain
          end
        end
      end
    end
  end
end
