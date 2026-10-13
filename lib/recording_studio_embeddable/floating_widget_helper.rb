# frozen_string_literal: true

module RecordingStudioEmbeddable
  # Local launcher markup. Uses the same JSON document as the public endpoint.
  module FloatingWidgetHelper
    def recording_studio_floating_label(recording)
      Floating::HostSettings.for(recording).fetch("label")
    end

    def recording_studio_floating_widget(recording:, preview: false, open: false)
      embed = floating_widget_embed(recording)
      return "".html_safe unless embed
      return "".html_safe unless preview || embed.floating_enabled?

      payload = Floating::LauncherConfig.call(
        embed: embed,
        recording: recording,
        request: request,
        preview: preview
      )
      return "".html_safe if payload.blank?

      recording_studio_widget_script_tag(payload, open: open && preview)
    end

    def recording_studio_widget_bridge_tag(parent_origin:)
      origin = parent_origin.to_s
      return "".html_safe if origin.blank? || origin == "*"

      tags = []
      tags << tag.meta(name: "recording-studio-widget-parent-origin", content: origin)
      tags << content_tag(:script, "", src: RecordingStudioEmbeddable::Engine.routes.url_helpers.widget_bridge_path)
      safe_join(tags)
    end

    def recording_studio_floating_widget_snippet(recording:, host: nil, protocol: nil)
      embed = floating_widget_embed(recording)
      return "" unless embed&.floating_enabled?

      source = recording_studio_widget_script_source(host: host, protocol: protocol)
      escaped_source = ERB::Util.html_escape(source)
      escaped_token = ERB::Util.html_escape(embed.token)
      %(<script async src="#{escaped_source}" data-embed="#{escaped_token}"></script>).html_safe
    end

    private

    def floating_widget_embed(recording)
      return unless recording.respond_to?(:floating_capable?) && recording.floating_capable?
      return unless recording.respond_to?(:embed)

      recording.embed
    end

    def recording_studio_widget_script_tag(payload, open:)
      data = { embed: payload.fetch("id"), config: payload.to_json }
      data[:preview_open] = "true" if open
      content_tag(
        :script,
        "",
        src: recording_studio_widget_script_source,
        async: true,
        data: data
      )
    end

    def recording_studio_widget_script_source(host: nil, protocol: nil)
      options = {}
      if host.present?
        options[:host] = host
        options[:protocol] = protocol if protocol.present?
        RecordingStudioEmbeddable::Engine.routes.url_helpers.widget_script_url(**options)
      else
        RecordingStudioEmbeddable::Engine.routes.url_helpers.widget_script_path
      end
    end
  end
end
