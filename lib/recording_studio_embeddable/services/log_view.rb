# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Services
    class LogView
      def self.call(embed:, payload:, status: "rendered", status_code: 200, cache_hit: false, rate_limited: false,
                    metadata: {})
        normalized = payload.symbolize_keys
        parent_recording = embed&.parent_recording
        parent_recordable = parent_recording&.recordable if parent_recording.respond_to?(:recordable)
        EmbeddableViewLog.create!(
          embed: embed,
          embed_recording_id: embed&.recording&.id,
          parent_recording_id: parent_recording&.id,
          parent_recordable_type: parent_recordable&.class&.name,
          parent_recordable_id: parent_recordable&.id,
          token_digest: digest(embed&.token || normalized[:token]),
          embed_mode: normalized[:embed_mode] || embed&.default_embed_mode,
          url_strategy: embed&.try(:embed_url_strategy),
          request_host: normalized[:request_host],
          request_path: normalized[:request_path],
          request_method: normalized[:request_method],
          viewed_at: normalized[:viewed_at] || Time.current,
          remote_ip_digest: digest(normalized[:ip]),
          user_agent_digest: digest(normalized[:user_agent]),
          viewer_digest: digest([normalized[:ip], normalized[:user_agent]].compact.join("|")),
          referer_host: host(normalized[:referer]),
          referer_digest: digest(normalized[:referer]),
          remote_ip: raw_value(normalized[:ip], :view_log_raw_ip),
          user_agent: raw_value(normalized[:user_agent], :view_log_raw_user_agent),
          referer: raw_value(normalized[:referer], :view_log_raw_referer),
          status: status,
          status_code: status_code,
          cache_hit: cache_hit,
          rate_limited: rate_limited,
          bot: BotDetector.bot?(normalized[:user_agent]),
          metadata: metadata
        )
      rescue StandardError => e
        if defined?(Rails) && Rails.logger
          Rails.logger.info("[RecordingStudioEmbeddable] view logging skipped: #{e.class}")
        end
        nil
      end

      def self.digest(value)
        return if value.blank?

        secret = if RecordingStudioEmbeddable.configuration.view_log_salt.present?
                   RecordingStudioEmbeddable.configuration.view_log_salt
                 elsif defined?(Rails) && Rails.application.respond_to?(:secret_key_base)
                   Rails.application.secret_key_base
                 else
                   "recording-studio-embeddable"
                 end
        OpenSSL::HMAC.hexdigest("SHA256", secret, value.to_s)
      end

      def self.host(value)
        return if value.blank?

        URI.parse(value.to_s).host&.downcase
      rescue URI::InvalidURIError
        nil
      end

      def self.raw_value(value, config_key)
        RecordingStudioEmbeddable.configuration.public_send(config_key) ? value : nil
      end
    end
  end
end
