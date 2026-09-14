# frozen_string_literal: true

module RecordingStudioEmbeddable
  class RenderMetadata
    attr_reader :etag_parts, :last_modified_at, :template

    def initialize(etag_parts:, last_modified_at:, template:)
      @etag_parts = Array(etag_parts)
      @last_modified_at = last_modified_at
      @template = template
    end
  end

  class BrowserPayload
    SCHEMA_VERSION = 1
    SDK_MINIMUM_VERSION = "0.3.0"

    attr_reader :schema_version, :html, :configuration, :sdk, :metadata

    def initialize(html:, configuration:, schema_version: SCHEMA_VERSION, sdk: nil, metadata: nil)
      @schema_version = schema_version
      @html = html.to_s
      @configuration = stringify_keys(configuration)
      @sdk = stringify_keys(sdk || { "minimum_version" => SDK_MINIMUM_VERSION })
      @metadata = metadata
    end

    def to_h
      {
        "schema_version" => schema_version,
        "html" => html,
        "configuration" => configuration,
        "sdk" => sdk
      }
    end

    private

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
  end
end
