# frozen_string_literal: true

module RecordingStudioEmbeddable
  module Cdn
    # DigitalOcean Spaces uploader (S3-compatible). Soft-requires +aws-sdk-s3+.
    class SpacesClient
      def initialize(
        endpoint: Credentials.spaces_endpoint,
        region: Credentials.spaces_region,
        bucket: Credentials.spaces_bucket,
        access_key_id: Credentials.spaces_access_key_id,
        secret_access_key: Credentials.spaces_secret_access_key
      )
        @endpoint = endpoint
        @region = region
        @bucket = bucket
        @access_key_id = access_key_id
        @secret_access_key = secret_access_key
      end

      def put_object(key:, body:, content_type:, cache_control:, metadata: {})
        client.put_object(
          bucket: @bucket,
          key: key,
          body: body,
          content_type: content_type,
          cache_control: cache_control,
          acl: "public-read",
          metadata: stringify_metadata(metadata)
        )
        { etag: nil, key: key }
      end

      private

      def client
        @client ||= begin
          require "aws-sdk-s3"
          Aws::S3::Client.new(
            access_key_id: @access_key_id,
            secret_access_key: @secret_access_key,
            endpoint: @endpoint,
            region: @region,
            force_path_style: false
          )
        end
      rescue LoadError
        raise LoadError, "aws-sdk-s3 is required to publish embeds to DigitalOcean Spaces. " \
                         "Add `gem \"aws-sdk-s3\"` to the host Gemfile."
      end

      def stringify_metadata(metadata)
        metadata.each_with_object({}) do |(key, value), result|
          next if value.nil?

          result[key.to_s] = value.to_s
        end
      end
    end
  end
end
