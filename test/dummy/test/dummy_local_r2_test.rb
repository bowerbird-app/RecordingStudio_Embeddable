# frozen_string_literal: true

require "test_helper"

class DummyLocalR2Test < ActiveSupport::TestCase
  test "example templates list key names without secret values" do
    yaml_example = Rails.root.join("config/local_r2.yml.example").read
    env_example = Rails.root.join(".env.development.local.example").read

    assert_includes yaml_example, "direct_url_host:"
    assert_includes yaml_example, "access_key_id:"
    assert_includes yaml_example, "secret_access_key:"
    assert_includes yaml_example, "r2_access_key_id:"
    assert_includes yaml_example, "r2_secret_access_key:"

    assert_includes env_example, "ATTACHABLE_DIRECT_URL_HOST="
    assert_includes env_example, "ARTIFACT_CDN_R2_ACCESS_KEY_ID="
    assert_includes env_example, "R2_ACCESS_KEY_ID="
    assert_includes env_example, "RECORDING_STUDIO_ARTIFACTS_ENABLED="

    refute_match(/\b(sk_|AKIA)[A-Za-z0-9]+/, yaml_example)
    refute_match(/\b(sk_|AKIA)[A-Za-z0-9]+/, env_example)
    refute_includes yaml_example, "dev_placeholder"
    refute_includes env_example, "dev_placeholder"
  end

  test "set_env never overwrites an existing ENV value" do
    key = "DUMMY_LOCAL_R2_TEST_#{SecureRandom.hex(4)}"
    ENV[key] = "already-set"
    DummyLocalR2.set_env(key, "replacement")
    assert_equal "already-set", ENV[key]
  ensure
    ENV.delete(key)
  end

  test "mirror_r2_env_aliases copies unset ARTIFACT_CDN_R2 from R2 aliases" do
    suffix = SecureRandom.hex(4)
    r2_key = "R2_ACCESS_KEY_ID_TEST_#{suffix}"
    artifact_key = "ARTIFACT_CDN_R2_ACCESS_KEY_ID_TEST_#{suffix}"

    # Exercise the real pair names with a temporary override of the pairs list
    # via the public set_env / mirror helpers on known keys.
    original_r2 = ENV["R2_BUCKET"]
    original_artifact = ENV["ARTIFACT_CDN_R2_BUCKET"]
    ENV.delete("ARTIFACT_CDN_R2_BUCKET")
    ENV["R2_BUCKET"] = "mirror-bucket-#{suffix}"

    DummyLocalR2.mirror_r2_env_aliases!

    assert_equal "mirror-bucket-#{suffix}", ENV["ARTIFACT_CDN_R2_BUCKET"]
  ensure
    if original_r2
      ENV["R2_BUCKET"] = original_r2
    else
      ENV.delete("R2_BUCKET")
    end
    if original_artifact
      ENV["ARTIFACT_CDN_R2_BUCKET"] = original_artifact
    else
      ENV.delete("ARTIFACT_CDN_R2_BUCKET")
    end
    ENV.delete(r2_key)
    ENV.delete(artifact_key)
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
