# frozen_string_literal: true

module RecordingStudioEmbeddable
  module RecordingMethods
    def embed
      embed_child_recording&.recordable
    end

    def current_embed
      embed
    end

    def embed_child_recording
      return unless defined?(RecordingStudio::Recording)

      scope = RecordingStudio::Recording
              .where(parent_recording_id: id, recordable_type: "RecordingStudioEmbeddable::Embed")
      scope = scope.where(trashed_at: nil) if RecordingStudioEmbeddable.recording_has_trashed_at?
      scope.first
    end

    def ensure_embed!(actor: nil, **attributes)
      raise NotEmbeddableError, "recording is not embeddable" unless embeddable?
      return embed if embed

      RecordingStudioEmbeddable::Embed.transaction do
        existing = embed
        return existing if existing

        embed_record = RecordingStudioEmbeddable::Embed.create!(attributes.reverse_merge(enabled: false))
        RecordingStudio::Recording.create!(recording_attributes_for_embed(embed_record))
        log_embeddable_event("embeddable.embed.created", actor: actor, embed: embed_record)
        embed_record
      end
    rescue ActiveRecord::RecordNotUnique
      reload.embed
    end

    def embeddable?
      options = RecordingStudioEmbeddable::Renderer.options_for(self)
      options[:enabled] == true
    end

    def embed_enabled?
      !!embed&.enabled?
    end

    def embed_public_path
      embed&.public_path
    end

    def embed_public_url(host: nil, protocol: nil)
      path = embed_public_path
      return unless path
      return path if host.blank?

      scheme = protocol || "https"
      "#{scheme}://#{host}#{path}"
    end

    def embed_code(**html_options)
      public_url = embed_public_url(**html_options.slice(:host, :protocol))
      return "" unless public_url

      title = ERB::Util.html_escape(html_options[:title] || "Embedded recording")
      src = ERB::Util.html_escape(public_url)
      sizing = embed&.sizing || {}
      iframe_width = html_options[:width].presence || sizing[:width].presence || sizing["width"].presence ||
                     sizing[:max_width].presence || sizing["max_width"].presence || "100%"
      iframe_height = html_options[:height].presence || sizing[:height].presence || sizing["height"].presence ||
                      sizing[:min_height].presence || sizing["min_height"].presence || "320px"
      [
        %(<iframe src="#{src}" title="#{title}" loading="lazy"),
        %(referrerpolicy="strict-origin-when-cross-origin" sandbox="allow-scripts allow-same-origin"),
        %(style="border:0;width:#{iframe_width};height:#{iframe_height};max-width:100%"></iframe>)
      ].join(" ")
    end

    def update_embed!(actor: nil, **attributes)
      ensure_embed!.update!(attributes)
      log_embeddable_event("embeddable.embed.updated", actor: actor, embed: embed)
      embed
    end

    def disable_embed!(actor: nil)
      update_embed!(actor: actor, enabled: false)
    end

    def enable_embed!(actor: nil)
      update_embed!(actor: actor, enabled: true)
    end

    private

    def recording_attributes_for_embed(embed_record)
      attrs = { recordable: embed_record, parent_recording_id: id }
      attrs[:root_recording_id] = root_recording_id.presence || id if respond_to?(:root_recording_id)
      attrs
    end

    def log_embeddable_event(name, actor:, embed:)
      return unless respond_to?(:log_event!)

      log_event!(name, actor: actor, metadata: { embed_id: embed.id })
    rescue StandardError
      nil
    end
  end

  class NotEmbeddableError < StandardError; end
end
