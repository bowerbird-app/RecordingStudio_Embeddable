# frozen_string_literal: true

module RecordingStudioEmbeddable
  class RenderPayload < Services::BaseService
    SIZING_KEYS = %w[width mode max_width min_height height].freeze

    def initialize(recording:, embed: nil, assigns: nil)
      super()
      @recording = recording
      @embed = embed
      @assigns = assigns || {}
    end

    private

    attr_reader :recording, :embed, :assigns

    def perform
      return failure("recording is required") if recording.blank?
      return failure("embed is required") if embed.nil?

      template = Renderer.resolve(recording, embed)
      theme = Renderer.embed_theme_for(recording, embed: embed)
      raw = render_fragment(template, theme)
      html = HtmlSanitizer.call(raw)
      configuration = {
        "theme" => stringify_keys(theme),
        "sizing" => allowlisted_sizing(embed)
      }
      metadata = RenderMetadata.new(
        etag_parts: [recording, embed, template, theme, configuration["sizing"]],
        last_modified_at: last_modified_at,
        template: template
      )

      success(
        BrowserPayload.new(
          html: html,
          configuration: configuration,
          metadata: metadata
        )
      )
    rescue StandardError => e
      failure(e)
    end

    def render_fragment(template, theme)
      renderer.render(
        template: template,
        layout: false,
        formats: [:html],
        assigns: fragment_assigns(theme)
      )
    end

    def fragment_assigns(theme)
      recordable = recording.respond_to?(:recordable) ? recording.recordable : nil
      base = {
        parent_recording: recording,
        parent_recordable: recordable,
        recordable: recordable,
        embed: embed,
        embed_theme: theme
      }
      base[recordable.model_name.element.to_sym] = recordable if recordable.respond_to?(:model_name)
      base.merge(assigns.transform_keys(&:to_sym))
    end

    def renderer
      if defined?(::ApplicationController) && ::ApplicationController.respond_to?(:renderer)
        ::ApplicationController.renderer
      else
        require "action_controller" unless defined?(ActionController::Base)
        ActionController::Base.renderer
      end
    end

    def allowlisted_sizing(embed_record)
      source = if embed_record.respond_to?(:sizing)
                 embed_record.sizing
               else
                 {}
               end
      source = source.respond_to?(:to_h) ? source.to_h : {}
      SIZING_KEYS.each_with_object({}) do |key, result|
        value = source[key] || source[key.to_sym]
        result[key] = value unless value.nil?
      end
    end

    def last_modified_at
      candidates = [
        (embed.updated_at if embed.respond_to?(:updated_at)),
        (recording.updated_at if recording.respond_to?(:updated_at)),
        (recording.recordable.updated_at if recording.respond_to?(:recordable) &&
          recording.recordable.respond_to?(:updated_at))
      ]
      candidates.compact.max
    end

    def stringify_keys(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested), result|
          result[key.to_s] = stringify_keys(nested)
        end
      when Array
        value.map { |entry| stringify_keys(entry) }
      else
        value
      end
    end

    def service_args
      { recording: recording, embed: embed, assigns: assigns }
    end
  end
end
