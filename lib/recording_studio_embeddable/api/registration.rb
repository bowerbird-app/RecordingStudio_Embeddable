# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Api
    module Registration
      class << self
        def register!
          return unless api_available?

          register_embed_action!
          register_enable_embed_action!
          register_disable_embed_action!
        end

        private

        def register_embed_action!
          if named_api_registration_supported?
            RecordingStudioApi.configuration.each_api do |api_definition|
              register_named_action!(DESCRIPTOR, api_name: api_definition.name, handler: EmbedRecording)
            end
          else
            register_legacy_action!(DESCRIPTOR, handler: EmbedRecording)
          end
        end

        def register_enable_embed_action!
          if named_api_registration_supported?
            register_named_action!(
              ENABLE_EMBED_DESCRIPTOR,
              api_name: PUBLIC_API,
              handler: EnableEmbedRecording
            )
          else
            register_legacy_action!(ENABLE_EMBED_DESCRIPTOR, handler: EnableEmbedRecording)
          end
        end

        def register_disable_embed_action!
          if named_api_registration_supported?
            register_named_action!(
              DISABLE_EMBED_DESCRIPTOR,
              api_name: PUBLIC_API,
              handler: DisableEmbedRecording
            )
          else
            register_legacy_action!(DISABLE_EMBED_DESCRIPTOR, handler: DisableEmbedRecording)
          end
        end

        def register_named_action!(descriptor, api_name:, handler:)
          name = descriptor[:name]
          return if RecordingStudioApi.capability_action(name, api: api_name)

          RecordingStudioApi.register_capability_action(
            name,
            api: api_name,
            **capability_action_options(descriptor, handler: handler)
          )
        end

        def register_legacy_action!(descriptor, handler:)
          name = descriptor[:name]
          return if RecordingStudioApi.capability_action(name)

          RecordingStudioApi.register_capability_action(
            name,
            **capability_action_options(descriptor, handler: handler)
          )
        end

        def named_api_registration_supported?
          RecordingStudioApi.respond_to?(:configuration) &&
            RecordingStudioApi.configuration.respond_to?(:each_api) &&
            action_api_accepts_api?(:capability_action) &&
            action_api_accepts_api?(:register_capability_action)
        end

        def action_api_accepts_api?(method_name)
          RecordingStudioApi.method(method_name).parameters.any? do |type, name|
            type == :keyrest || (name == :api && %i[key keyreq].include?(type))
          end
        end

        def capability_action_options(descriptor, handler:)
          {
            capability: descriptor[:capability],
            version: descriptor[:version],
            version_notes: descriptor[:version_notes],
            http_verb: descriptor[:http_verb],
            scope: descriptor[:scope],
            required_role: descriptor[:required_role],
            handler: handler,
            openapi: OpenapiOverrides.default_openapi(action: descriptor[:name]),
            openapi_for: ->(type:, action:) { Api.openapi_for(type: type, action: action) }
          }
        end

        def api_available?
          defined?(RecordingStudioApi) &&
            RecordingStudioApi.respond_to?(:capability_action) &&
            RecordingStudioApi.respond_to?(:register_capability_action)
        end
      end
    end
  end
end
