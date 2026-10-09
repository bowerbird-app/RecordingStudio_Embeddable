# frozen_string_literal: true

require "test_helper"
require "yaml"
require "active_support/encrypted_file"

class DummyCredentialsTest < Minitest::Test
  PLACEHOLDER = "dev_placeholder"

  CDN_CREDENTIAL_KEYS = %w[
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

  def test_only_dummy_credentials_files_are_committed
    tracked = Dir.chdir(File.expand_path("..", __dir__)) do
      `git ls-files -- '*.yml.enc'`.split("\n").reject(&:empty?).sort
    end

    assert_equal [
      "test/dummy/config/credentials.yml.enc",
      "test/dummy/config/credentials/development.yml.enc",
      "test/dummy/config/credentials/test.yml.enc"
    ], tracked

    tracked_keys = Dir.chdir(File.expand_path("..", __dir__)) do
      `git ls-files -- '**/credentials/*.key' '**/master.key'`.split("\n").reject(&:empty?)
    end
    assert_empty tracked_keys, "credential keys must never be committed"

    %w[
      test/dummy/config/credentials/development.key
      test/dummy/config/credentials/test.key
      test/dummy/config/master.key
      config/master.key
    ].each do |key_path|
      refute_includes tracked_keys, key_path, "#{key_path} must never be tracked"
    end
  end

  def test_encrypted_credentials_file_is_present
    path = dummy_credentials_path
    assert File.exist?(path), "Expected #{path} so new gems reuse the shared dummy credentials"
    assert File.size(path).positive?
  end

  def test_master_key_is_gitignored_and_untracked
    gitignore = File.read(File.expand_path("../.gitignore", __dir__))
    assert_includes gitignore, "test/dummy/config/master.key"
    assert_includes gitignore, "config/master.key"
    assert_includes gitignore, "test/dummy/config/credentials/*.key"
    assert_includes gitignore, "test/dummy/config/credentials/development.key"
    assert_includes gitignore, "test/dummy/config/credentials/test.key"

    tracked = Dir.chdir(File.expand_path("..", __dir__)) do
      `git ls-files -- config/master.key test/dummy/config/master.key test/dummy/config/credentials/development.key test/dummy/config/credentials/test.key`.strip
    end
    assert_equal "", tracked, "master.key and credentials/*.key must not be committed"
  end

  def test_dummy_credentials_decrypt_when_master_key_is_available
    skip "Set RAILS_MASTER_KEY or test/dummy/config/master.key to the shared dummy key" unless master_key_available?

    parsed = YAML.safe_load(
      ActiveSupport::EncryptedFile.new(
        content_path: dummy_credentials_path,
        key_path: dummy_master_key_path,
        env_key: "RAILS_MASTER_KEY",
        raise_if_missing_key: true
      ).read
    )

    assert_operator parsed.fetch("secret_key_base").to_s.length, :>=, 64
    assert_equal PLACEHOLDER, parsed.dig("gem_template", "api_key")
    assert_equal PLACEHOLDER, parsed.dig("smtp", "user_name")
    assert_equal PLACEHOLDER, parsed.dig("smtp", "password")
    assert_equal PLACEHOLDER, parsed.dig("aws", "access_key_id")
    assert_equal PLACEHOLDER, parsed.dig("aws", "secret_access_key")
    assert_equal PLACEHOLDER, parsed.dig("recording_studio_artifacts", "api_key")

    cdn = parsed.dig("recording_studio_artifacts", "cdn")
    assert_kind_of Hash, cdn, "Expected recording_studio_artifacts.cdn in shared dummy credentials"
    CDN_CREDENTIAL_KEYS.each do |key|
      assert cdn.key?(key), "Expected recording_studio_artifacts.cdn.#{key} in shared dummy credentials"
    end
    assert_equal "https://artifacts.example.test", cdn.fetch("public_base_url")
    assert_equal PLACEHOLDER, cdn.fetch("r2_secret_access_key")
  end

  def test_cdn_credential_env_names_are_documented_for_hosts
    docs = File.read(File.expand_path("../docs/CDN.md", __dir__))
    %w[
      ARTIFACT_CDN_SUBDOMAIN
      ARTIFACT_CDN_DOMAIN
      ARTIFACT_CDN_PATH_PREFIX
      ARTIFACT_CDN_PUBLIC_BASE_URL
      ARTIFACT_CDN_R2_ACCOUNT_ID
      ARTIFACT_CDN_R2_ACCESS_KEY_ID
      ARTIFACT_CDN_R2_SECRET_ACCESS_KEY
      ARTIFACT_CDN_R2_BUCKET
      ARTIFACT_CDN_CLOUDFLARE_ZONE_ID
      ARTIFACT_CDN_CLOUDFLARE_API_TOKEN
    ].each do |env_name|
      assert_includes docs, env_name
    end
    assert_includes docs, "recording_studio_artifacts.cdn"
  end

  private

  def dummy_credentials_path
    File.expand_path("../test/dummy/config/credentials.yml.enc", __dir__)
  end

  def dummy_master_key_path
    File.expand_path("../test/dummy/config/master.key", __dir__)
  end

  def master_key_available?
    ENV["RAILS_MASTER_KEY"].to_s.strip.present? || File.exist?(dummy_master_key_path)
  end
end
