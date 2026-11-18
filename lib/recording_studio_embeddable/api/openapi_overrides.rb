# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Api
    module OpenapiOverrides
      class << self
        def write(type:, action:, title:, description:)
          type_name = type_name!(type)
          action_name = action_name!(action)
          raise ArgumentError, "title is required" if blank?(title)

          entry = { title: title }
          entry[:description] = description unless description.nil?
          entries[[type_name, action_name]] = entry.freeze
          nil
        end

        def document(type:, action:)
          action_name = action_name!(action)
          base = default_openapi
          entry = entries[[type.to_s, action_name]]
          entry ? base.merge(entry) : base
        end

        def default_openapi
          {
            summary: ACTION_SUMMARY,
            description: ACTION_DESCRIPTION,
            responses: ACTION_RESPONSE_DESCRIPTIONS.transform_values { |text| { description: text } }
          }
        end

        def reset!
          @entries = {}
        end

        private

        def entries
          @entries ||= {}
        end

        def type_name!(type)
          type_name = type.to_s
          raise ArgumentError, "type is required" if type_name.strip.empty?

          type_name
        end

        def action_name!(action)
          raise ArgumentError, "Unknown Embeddable action #{action.inspect}" unless action.respond_to?(:to_sym)

          name = action.to_sym
          return name if name == :embed

          raise ArgumentError, "Unknown Embeddable action #{action.inspect}"
        end

        def blank?(title)
          title.nil? || title.to_s.strip.empty?
        end
      end
    end
  end
end
