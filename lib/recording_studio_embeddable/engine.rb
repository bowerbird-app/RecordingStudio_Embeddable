# frozen_string_literal: true

module RecordingStudioEmbeddable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioEmbeddable

    initializer "recording_studio_embeddable.load_config" do |app|
      if app.respond_to?(:config_for)
        begin
          yaml = app.config_for(:recording_studio_embeddable)
          RecordingStudioEmbeddable.configuration.merge!(yaml) if yaml.respond_to?(:each)
        rescue StandardError
          nil
        end
      end

      next unless app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_embeddable)

      xcfg = app.config.x.recording_studio_embeddable
      RecordingStudioEmbeddable.configuration.merge!(xcfg.respond_to?(:to_h) ? xcfg.to_h : xcfg)
    end

    initializer "recording_studio_embeddable.recording_methods" do
      ActiveSupport.on_load(:active_record) do
        include RecordingStudioEmbeddable::Recordable
      end

      config.to_prepare do
        next unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.include RecordingStudioEmbeddable::Recordable

        if defined?(RecordingStudio::Recording)
          RecordingStudio::Recording.include RecordingStudioEmbeddable::RecordingMethods
        end
      end
    end
  end
end
