# frozen_string_literal: true

module RecordingStudioEmbeddable
  class Renderer
    FALLBACK = "recording_studio_embeddable/embeds/default"
    DEFAULT_LAYOUT = "recording_studio_embeddable/embed"

    def self.resolve(recording, _embed)
      options = options_for(recording)
      configured = normalize(options[:renderer])
      return configured[:template] if configured[:template].present?
      explicit_controller = options[:embed_controller].presence || options[:public_controller].presence
      explicit_action = options[:embed_action].presence || options[:public_action].presence
      if explicit_controller && explicit_action
        return "#{explicit_controller}/#{explicit_action}"
      end

      resolver = RecordingStudioEmbeddable.configuration.embed_renderer_resolver ||
                 RecordingStudioEmbeddable.configuration.renderer_resolver
      if resolver.respond_to?(:call)
        resolved = resolver.call(
          recordable_type: recording&.recordable_type,
          recordable_class: recording&.recordable&.class,
          default_renderer: convention_for(recording)
        )
      end
      resolved = normalize(resolved)
      return resolved[:template] if resolved[:template].present?

      convention = convention_for(recording)
      return convention[:template] if convention[:template].present? && template_exists?(convention[:template])
      if convention[:fallback_template].present? && template_exists?(convention[:fallback_template])
        return convention[:fallback_template]
      end

      FALLBACK
    end

    def self.details(recording, _embed)
      normalize(options_for(recording)[:renderer]).presence ||
        normalize(convention_for(recording)).merge(source: :convention, layout: DEFAULT_LAYOUT)
    end

    def self.layout_for(recording, embed)
      details(recording, embed)[:layout].presence || DEFAULT_LAYOUT
    end

    def self.embed_theme_for(recording)
      global_theme = normalize_theme_hash(RecordingStudioEmbeddable.configuration.embed_theme)
      recordable_theme = normalize_theme_hash(options_for(recording)[:embed_theme])
      custom_properties = global_theme.fetch(:custom_properties, {}).merge(recordable_theme.fetch(:custom_properties, {}))

      global_theme.merge(recordable_theme).merge(custom_properties: custom_properties)
    end

    def self.options_for(recording)
      recordable = recording.respond_to?(:recordable) ? recording.recordable : nil
      from_macro(recordable).merge(from_capabilities(recordable))
    end

    def self.from_macro(recordable)
      klass = recordable&.class
      klass.respond_to?(:recording_studio_embeddable_options) ? (klass.recording_studio_embeddable_options || {}) : {}
    end

    def self.from_capabilities(recordable)
      klass = recordable&.class
      candidates = []
      candidates.concat(Array(klass.recording_studio_capabilities)) if klass.respond_to?(:recording_studio_capabilities)
      if recordable.respond_to?(:recording_studio_capabilities)
        candidates.concat(Array(recordable.recording_studio_capabilities))
      end
      capability = candidates.find { |candidate| candidate.respond_to?(:key) && candidate.key.to_sym == :embeddable }
      capability.respond_to?(:options) ? capability.options : {}
    end

    def self.normalize(renderer)
      case renderer
      when Hash
        renderer.symbolize_keys
      when String, Symbol
        { template: renderer.to_s }
      else
        {}
      end
    end

    def self.convention_for(recording)
      recordable = recording&.recordable
      klass = recordable&.class
      return {} unless klass&.respond_to?(:model_name)

      options = options_for(recording)
      explicit_controller = options[:embed_controller].presence || options[:public_controller].presence
      explicit_action = options[:embed_action].presence || options[:public_action].presence
      if explicit_controller && explicit_action
        return {
          controller: explicit_controller,
          action: explicit_action.to_sym,
          template: "#{explicit_controller}/#{explicit_action}",
          fallback_template: "#{explicit_controller}/embed",
          layout: DEFAULT_LAYOUT
        }
      end

      plural = klass.model_name.route_key
      if publishable_recordable?(recordable)
        return {
          controller: plural,
          action: :show,
          template: "#{plural}/show",
          fallback_template: "#{plural}/embed",
          layout: DEFAULT_LAYOUT
        }
      end

      {
        controller: plural,
        action: :embed,
        template: "#{plural}/embed",
        layout: DEFAULT_LAYOUT
      }
    end

    def self.publishable_recordable?(recordable)
      klass = recordable.class
      klass.respond_to?(:recording_studio_publishable_options) ||
        recordable.respond_to?(:recording_studio_publishable_options)
    end

    def self.template_exists?(path)
      return false unless defined?(ActionController::Base)

      ActionView::LookupContext.new(ActionController::Base.view_paths).exists?(path, [], false)
    end

    def self.normalize_theme_hash(theme)
      return { custom_properties: {} } unless theme.respond_to?(:to_h)

      normalized = theme.to_h.symbolize_keys
      normalized[:custom_properties] = normalized.fetch(:custom_properties, {}).to_h.stringify_keys
      normalized
    end
  end
end
