# frozen_string_literal: true

require "test_helper"

class DummyDevCredentialsTest < ActiveSupport::TestCase
  test "development credentials example lists key names without secret values" do
    example = Rails.root.join("config/credentials/development.yml.example").read

    assert_includes example, "r2:"
    assert_includes example, "access_key_id:"
    assert_includes example, "secret_access_key:"
    assert_includes example, "endpoint:"
    assert_includes example, "bucket:"
    assert_includes example, "recording_studio_artifacts:"
    assert_includes example, "r2_access_key_id:"
    assert_includes example, "r2_secret_access_key:"
    assert_includes example, "recording_studio_attachable:"
    assert_includes example, "direct_url_host:"
    assert_includes example, "secret_key_base:"

    refute_match(/\b(sk_|AKIA)[A-Za-z0-9]+/, example)
    refute_includes example, "dev_placeholder"
  end

  test "credential key files stay gitignored and untracked" do
    gitignore = File.read(Rails.root.join("../../.gitignore"))
    repo_root = Rails.root.join("../..")

    %w[
      test/dummy/config/credentials/*.key
      test/dummy/config/credentials/development.key
      test/dummy/config/credentials/test.key
      test/dummy/config/master.key
    ].each do |pattern|
      assert_includes gitignore, pattern
    end

    %w[
      test/dummy/config/credentials/development.key
      test/dummy/config/credentials/test.key
      test/dummy/config/master.key
    ].each do |key_path|
      tracked = `git -C #{repo_root} ls-files --error-unmatch #{key_path} 2>/dev/null`
      assert_equal "", tracked.to_s.strip, "#{key_path} must never be tracked by git"
    end
  end

  test "test env does not require a master key when test.yml.enc is present" do
    assert_equal false, Rails.application.config.require_master_key
    assert Rails.root.join("config/credentials/test.yml.enc").exist?
  end

  test "artifacts_cdn_configured is independent of Active Storage r2 keys" do
    # In test, shared credentials either lack CDN keys or use placeholders that dig ignores.
    refute DummyDevCredentials.artifacts_cdn_configured?
    assert_kind_of RecordingStudioArtifacts::Cdn::MemoryStorage,
                   RecordingStudioArtifacts.configuration.cdn_storage
  end

  test "dig returns nil for missing paths without raising" do
    assert_nil DummyDevCredentials.dig(:definitely_missing, :path)
  end

  test "dig ignores placeholders and missing CDN secrets" do
    # test.yml.enc / development.yml.enc omit Artifacts CDN secrets; shared
    # credentials.yml.enc uses dev_placeholder (filtered by dig). Either way,
    # dig must not surface a usable CDN secret in this suite.
    assert_nil DummyDevCredentials.dig(:recording_studio_artifacts, :cdn, :r2_secret_access_key)
  end

  test "attachable direct_url_host falls back to dummy stand-in without decryptable credentials" do
    configured = DummyDevCredentials.dig(:recording_studio_attachable, :direct_url_host)
    host = RecordingStudioAttachable.configuration.direct_url_host

    if configured.present?
      assert_equal configured, host
    else
      assert_equal "cdn.example.test", host
    end
  end

  test "artifacts cdn public base falls back to dummy stand-in" do
    assert_equal "https://artifacts.example.test",
                 RecordingStudioArtifacts.configuration.cdn_public_base_url
  end

  test "seeds attach press kit images to every embeddable example" do
    seeds = File.read(Rails.root.join("db/seeds.rb"))

    assert_includes seeds, "seed_press_kit_on.call(page_recording)"
    assert_includes seeds, "seed_press_kit_on.call(article_recording)"
    assert_includes seeds, "import_attachment"
    assert RecordingStudio.capability_enabled?(:attachable, for: "Page")
    assert RecordingStudio.capability_enabled?(:attachable, for: "Article")
  end
end
