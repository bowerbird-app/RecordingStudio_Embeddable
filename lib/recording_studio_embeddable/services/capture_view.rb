# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Services
    class CaptureView
      def self.call(embed:, request:, status: "rendered", status_code: 200, cache_hit: false, rate_limited: false,
                    metadata: {})
        return unless RecordingStudioEmbeddable.configuration.view_logging_enabled

        sample_rate = selected_sample_rate
        return if sample_rate.nil?

        payload = NormalizePayload.call(request)
        logged_metadata = metadata.to_h.stringify_keys.merge("sample_rate" => sample_rate)
        if RecordingStudioEmbeddable.configuration.async_view_logging && defined?(RecordingStudioEmbeddable::LogViewJob)
          RecordingStudioEmbeddable::LogViewJob.perform_later(embed&.id, payload, status, status_code, cache_hit,
                                                              rate_limited, logged_metadata)
        else
          LogView.call(embed: embed, payload: payload, status: status, status_code: status_code,
                       cache_hit: cache_hit, rate_limited: rate_limited, metadata: logged_metadata)
        end
      rescue StandardError => e
        if defined?(Rails) && Rails.logger
          Rails.logger.info("[RecordingStudioEmbeddable] view capture skipped: #{e.class}")
        end
        nil
      end

      # 0 logs nothing. 1 logs every view. Anything in between logs about that
      # fraction. Rates above 1 log every view and are stored as 1 so stats do
      # not shrink the total. Returns nil when this view should be dropped.
      def self.selected_sample_rate
        rate = RecordingStudioEmbeddable.configuration.view_log_success_sample_rate.to_f
        return if rate <= 0
        return 1.0 if rate >= 1.0
        return if random_draw >= rate

        rate
      end

      def self.random_draw
        Kernel.rand
      end
      private_class_method :selected_sample_rate, :random_draw
    end
  end
end
