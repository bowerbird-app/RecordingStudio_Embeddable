# frozen_string_literal: true

begin
  require "recording_studio_publishable"
rescue LoadError
  nil
end

if defined?(RecordingStudioPublishable)
  RecordingStudioPublishable.configure do |config|
    config.management_close_url_resolver = lambda do |controller:, recording: nil|
      _ = recording
      controller&.main_app&.root_path || "/"
    end
  end

  module RecordingStudioPublishableDummyRecordingCacheFix
    def publishable_child_recording
      cached = @publishable_child_recording if instance_variable_defined?(:@publishable_child_recording)
      return cached if cached.present?

      @publishable_child_recording = self.class.where(
        parent_recording_id: id,
        recordable_type: RecordingStudioPublishable::Publishable.name,
        trashed_at: nil
      ).order(:created_at, :id).first
    end

    def current_publishable
      cached = @current_publishable if instance_variable_defined?(:@current_publishable)
      return cached if cached.present?

      @current_publishable = publishable_child_recording&.recordable
    end
  end

  Rails.application.config.to_prepare do
    next unless defined?(RecordingStudio::Recording)
    next if RecordingStudio::Recording < RecordingStudioPublishableDummyRecordingCacheFix

    RecordingStudio::Recording.prepend(RecordingStudioPublishableDummyRecordingCacheFix)
  end
end
