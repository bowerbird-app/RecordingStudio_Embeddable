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

  test "development.key is gitignored and development.yml.enc is not required for CI" do
    gitignore = File.read(Rails.root.join("../../.gitignore"))

    assert_includes gitignore, "test/dummy/config/credentials/development.key"
    assert_includes gitignore, "test/dummy/config/credentials/*.key"

    key_path = Rails.root.join("config/credentials/development.key")
    if key_path.exist?
      tracked = `git -C #{Rails.root.join("../..")} ls-files --error-unmatch config/credentials/development.key 2>/dev/null`
      # Prefer checking from repo root path used by gitignore.
      tracked = `git -C #{Rails.root.join("../..")} ls-files --error-unmatch test/dummy/config/credentials/development.key 2>/dev/null`
      assert_equal "", tracked.to_s.strip, "development.key must never be tracked by git"
    end
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

  test "dig ignores shared credential placeholders" do
    skip "Set RAILS_MASTER_KEY or test/dummy/config/master.key" unless DummyDevCredentials.credentials_readable?

    # Shared credentials.yml.enc uses dev_placeholder under recording_studio_artifacts.cdn
    assert_nil DummyDevCredentials.dig(:recording_studio_artifacts, :cdn, :r2_secret_access_key)
  end

  test "attachable direct_url_host falls back to dummy stand-in" do
    assert_equal "cdn.example.test", RecordingStudioAttachable.configuration.direct_url_host
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
