# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Security
    class PublicAccess
      Result = Struct.new(:allowed?, :status, :reason, :domain_policy, keyword_init: true)

      def self.call(...)
        new(...).call
      end

      def initialize(embed:, request:, recording:, options: {})
        @embed = embed
        @request = request
        @recording = recording
        @options = options || {}
      end

      def call
        return deny(:not_found, :disabled) unless RecordingStudioEmbeddable.configuration.public_embeds_enabled
        return deny(:not_found, :not_found) unless embed&.enabled?
        return deny(:not_found, :missing_recording) unless recording
        return deny(:not_found, :not_embeddable) unless embeddable_recordable?
        return deny(:not_found, :unpublished) unless publishable_allowed?
        return deny(:not_found, :unpublished) unless recordable_allows_public_embed?
        return deny(:forbidden, :domain_blocked) unless domain_policy.allowed?

        Result.new(allowed?: true, status: :ok, reason: :ok, domain_policy: domain_policy)
      end

      private

      attr_reader :embed, :request, :recording, :options

      def deny(status, reason)
        Result.new(allowed?: false, status: status, reason: reason, domain_policy: domain_policy)
      end

      def domain_policy
        @domain_policy ||= DomainPolicy.new(
          embed: embed,
          origin: request.get_header("HTTP_ORIGIN"),
          referer: request.referer,
          request_host: request.respond_to?(:host) ? request.host : nil,
          options: options
        )
      end

      def publishable_allowed?
        required = options.fetch(:require_publishable, RecordingStudioEmbeddable.configuration.require_publishable)
        return true unless required

        return !!recording.currently_published? if recording.respond_to?(:currently_published?)
        return !!recording.current_publishable if recording.respond_to?(:current_publishable)
        return !!recording.publishable_child_recording if recording.respond_to?(:publishable_child_recording)

        false
      end

      def recordable_allows_public_embed?
        recordable = recording.recordable if recording.respond_to?(:recordable)
        return true unless recordable.respond_to?(:public_embed_allowed?, true)
        return false unless recordable.respond_to?(:public_embed_allowed?)

        recordable.public_embed_allowed?(viewer: viewer) == true
      rescue StandardError => e
        warn_refused_public_embed(e.class)
        false
      end

      # Public iframe, launcher, and popup requests are anonymous.
      def viewer
        nil
      end

      def warn_refused_public_embed(error_class)
        return unless defined?(Rails) && Rails.respond_to?(:logger)

        Rails.logger&.warn("[RecordingStudioEmbeddable] public_embed_allowed? failed (#{error_class})")
      end

      def embeddable_recordable?
        options[:enabled] == true
      end
    end
  end
end
