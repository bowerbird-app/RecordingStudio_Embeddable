# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Services
    # Processes Attachable preprocessed variants before CDN HTML is rendered.
    #
    # Artifacts-published HTML must never include Attachable's Rails preview
    # fallback. This service runs +PreprocessVariantsJob+ synchronously for
    # every image on the recording, then verifies +variant_processed?+ for each
    # configured preprocessed name. Callers defer publish when verification fails.
    class EnsureEmbedImageVariants < BaseService
      def initialize(recording:)
        super()
        @recording = recording
      end

      private

      attr_reader :recording

      def perform
        return success(attachments: [], variants: []) unless attachable_available?
        return success(attachments: [], variants: []) unless recording.respond_to?(:images)

        attachments = image_attachments
        return success(attachments: [], variants: []) if attachments.empty?

        variants = preprocessed_variant_names
        attachments.each { |attachment| process_attachment!(attachment) }

        missing = missing_variants(attachments, variants)
        if missing.any?
          return failure(
            "Embed image variants are not processed yet: #{missing.map do |row|
              "#{row[:attachment_id]}:#{row[:variant]}"
            end.join(', ')}"
          )
        end

        success(attachments: attachments, variants: variants)
      rescue StandardError => e
        failure(e)
      end

      def attachable_available?
        defined?(RecordingStudioAttachable::PreprocessVariantsJob) &&
          defined?(RecordingStudioAttachable::Attachment)
      end

      def image_attachments
        recordings = Array(recording.images(per_page: 100))
        recordings.filter_map do |image_recording|
          recordable = image_recording.respond_to?(:recordable) ? image_recording.recordable : image_recording
          next unless recordable.is_a?(RecordingStudioAttachable::Attachment)
          next unless recordable.file.attached?
          next unless recordable.file.variable?

          recordable
        end
      end

      def preprocessed_variant_names
        names = RecordingStudioAttachable.configuration.preprocessed_variants
        Array(names).map(&:to_sym)
      end

      def process_attachment!(attachment)
        RecordingStudioAttachable::PreprocessVariantsJob.perform_now(attachment.id)
        attachment.file.reload if attachment.file.respond_to?(:reload)
      end

      def missing_variants(attachments, variants)
        attachments.flat_map do |attachment|
          variants.filter_map do |variant_name|
            next if attachment.variant_processed?(variant_name)

            { attachment_id: attachment.id, variant: variant_name }
          end
        end
      end

      def service_args
        { recording_id: recording.respond_to?(:id) ? recording.id : nil }
      end
    end
  end
end
