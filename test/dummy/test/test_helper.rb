# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    def grant_embed_management!(actor:, recording:)
      return if RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :edit)

      result = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: actor)
      raise result.error unless result.success?
    end
  end
end
