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

  module RecordingStudioPublishableDummyPageNavCloseUrlCompat
    def initialize(close_url: nil, anchor_url: nil, **system_arguments)
      anchor_url ||= close_url
      super(anchor_url: anchor_url, **system_arguments)
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

  Rails.application.config.to_prepare do
    next unless defined?(FlatPack::PageNav::Component)

    initialize_params = FlatPack::PageNav::Component.instance_method(:initialize).parameters
    has_anchor_url = initialize_params.any? { |(_, name)| name == :anchor_url }
    has_close_url = initialize_params.any? { |(_, name)| name == :close_url }

    next unless has_anchor_url
    next if has_close_url
    next if FlatPack::PageNav::Component < RecordingStudioPublishableDummyPageNavCloseUrlCompat

    FlatPack::PageNav::Component.prepend(RecordingStudioPublishableDummyPageNavCloseUrlCompat)
  end
end
