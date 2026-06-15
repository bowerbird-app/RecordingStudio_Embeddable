# frozen_string_literal: true

require "recording_studio_embeddable/version"
require "openssl"
require "uri"
require "recording_studio_embeddable/hooks"
require "recording_studio_embeddable/configuration"
require "recording_studio_embeddable/recordable"
require "recording_studio_embeddable/capabilities/embeddable"
require "recording_studio_embeddable/engine"

module RecordingStudioEmbeddable
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def recording_has_trashed_at?
      return false unless defined?(RecordingStudio::Recording)
      return false unless RecordingStudio::Recording.respond_to?(:column_names)

      RecordingStudio::Recording.column_names.include?("trashed_at")
    rescue StandardError
      false
    end
  end
end
