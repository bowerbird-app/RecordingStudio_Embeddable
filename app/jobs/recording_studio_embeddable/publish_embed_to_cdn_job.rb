# frozen_string_literal: true

module RecordingStudioEmbeddable
  class PublishEmbedToCdnJob < ActiveJob::Base
    queue_as { RecordingStudioEmbeddable.configuration.cdn_publish_queue || :default }

    retry_on StandardError, attempts: 5

    def perform(embed_id)
      embed = Embed.find_by(id: embed_id)
      return if embed.blank?
      return unless embed.cdn_url_strategy?

      result = Services::PublishEmbedToCdn.call(embed: embed)
      raise result.error if result.failure?
    end
  end
end
