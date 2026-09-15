# frozen_string_literal: true

require "loofah"

module RecordingStudioEmbeddable
  class HtmlSanitizer
    FORBIDDEN_ELEMENTS = %w[script iframe object embed link meta].freeze
    URL_ATTRIBUTES = %w[href src xlink:href].freeze

    class Scrubber < Loofah::Scrubber
      def scrub(node)
        return CONTINUE unless node.element?

        if FORBIDDEN_ELEMENTS.include?(node.name)
          node.remove
          return STOP
        end

        node.attribute_nodes.each do |attribute|
          name = attribute.name.to_s
          next unless name.start_with?("on") ||
                      (URL_ATTRIBUTES.include?(name) && javascript_url?(attribute.value))

          node.remove_attribute(name)
        end

        CONTINUE
      end

      private

      def javascript_url?(value)
        value.to_s.strip.match?(/\Ajavascript:/i)
      end
    end

    def self.call(html)
      Loofah.fragment(html.to_s).scrub!(Scrubber.new).to_s
    end
  end
end
