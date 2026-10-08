# frozen_string_literal: true

require "test_helper"

class CredentialsTest < ActiveSupport::TestCase
  CDN_CREDENTIAL_KEYS = %i[
    subdomain
    domain
    path_prefix
    public_base_url
    r2_account_id
    r2_access_key_id
    r2_secret_access_key
    r2_bucket
    r2_endpoint
    r2_region
    cloudflare_zone_id
    cloudflare_api_token
  ].freeze

  test "dummy credentials expose shared keys when the master key is available" do
    skip "Set RAILS_MASTER_KEY or test/dummy/config/master.key to the shared dummy key" unless master_key_available?

    credentials = Rails.application.credentials
    assert credentials.secret_key_base.present?
    assert_equal "dev_placeholder", credentials.dig(:gem_template, :api_key)
    assert_equal "dev_placeholder", credentials.dig(:smtp, :user_name)
    assert_equal "dev_placeholder", credentials.dig(:smtp, :password)
    assert_equal "dev_placeholder", credentials.dig(:aws, :access_key_id)
    assert_equal "dev_placeholder", credentials.dig(:aws, :secret_access_key)
    assert_equal "dev_placeholder", credentials.dig(:recording_studio_artifacts, :api_key)

    cdn = credentials.dig(:recording_studio_artifacts, :cdn)
    assert_kind_of Hash, cdn
    CDN_CREDENTIAL_KEYS.each do |key|
      assert cdn.key?(key), "Expected recording_studio_artifacts.cdn.#{key}"
    end
    assert_equal "https://artifacts.example.test", cdn.fetch(:public_base_url)
    assert_equal "dev_placeholder", cdn.fetch(:r2_secret_access_key)
  end

  private

  def master_key_available?
    ENV["RAILS_MASTER_KEY"].to_s.strip.present? || File.exist?(Rails.root.join("config/master.key"))
  end
end
