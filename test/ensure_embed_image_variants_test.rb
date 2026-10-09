# frozen_string_literal: true

require "test_helper"

class EnsureEmbedImageVariantsTest < Minitest::Test
  def test_succeeds_when_recording_has_no_images_api
    recording = Object.new
    result = RecordingStudioEmbeddable::Services::EnsureEmbedImageVariants.call(recording: recording)

    assert result.success?
    assert_equal [], result.value[:attachments]
  end

  def test_reports_failure_when_variants_remain_unprocessed
    skip "RecordingStudioAttachable not loaded" unless defined?(RecordingStudioAttachable::PreprocessVariantsJob)
    skip "Attachment class missing" unless defined?(RecordingStudioAttachable::Attachment)

    attachment = Object.new
    attachment.define_singleton_method(:id) { "att-1" }
    file = Object.new
    file.define_singleton_method(:attached?) { true }
    file.define_singleton_method(:variable?) { true }
    file.define_singleton_method(:reload) { file }
    attachment.define_singleton_method(:file) { file }
    attachment.define_singleton_method(:variant_processed?) { |_name| false }
    attachment.define_singleton_method(:is_a?) do |klass|
      klass == RecordingStudioAttachable::Attachment
    end

    image_recording = Object.new
    image_recording.define_singleton_method(:recordable) { attachment }

    recording = Object.new
    recording.define_singleton_method(:id) { "rec-1" }
    recording.define_singleton_method(:images) { |**_| [image_recording] }

    performed = []
    job = RecordingStudioAttachable::PreprocessVariantsJob
    original_job = job.method(:perform_now)
    job.define_singleton_method(:perform_now) { |id| performed << id }

    config = RecordingStudioAttachable.configuration
    original_variants = config.method(:preprocessed_variants)
    config.define_singleton_method(:preprocessed_variants) { %i[small med large] }

    result = RecordingStudioEmbeddable::Services::EnsureEmbedImageVariants.call(recording: recording)
    refute result.success?, "expected failure when variants stay unprocessed"
    assert_match(/not processed yet/, result.error.to_s)
    assert_equal ["att-1"], performed
  ensure
    job.define_singleton_method(:perform_now, original_job) if job && original_job
    config.define_singleton_method(:preprocessed_variants, original_variants) if config && original_variants
  end
end
