# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ArtifactsHomeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "artifacts-home@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in @user
    @previous_artifacts_enabled = RecordingStudioEmbeddable.configuration.artifacts_enabled
  end

  teardown do
    RecordingStudioEmbeddable.configuration.artifacts_enabled = @previous_artifacts_enabled
  end

  test "artifacts engine home renders a real page when artifacts is off" do
    RecordingStudioEmbeddable.configuration.artifacts_enabled = false

    get "/recording_studio_artifacts"

    assert_response :success
    assert_operator response.body.bytesize, :>, 200
    assert_includes response.body, "RecordingStudio Artifacts"
    assert_includes response.body, "Artifacts is off"
    assert_includes response.body, "artifacts_enabled"
  end

  test "artifacts engine home renders a real page when artifacts is on" do
    RecordingStudioEmbeddable.configuration.artifacts_enabled = true

    get "/recording_studio_artifacts"

    assert_response :success
    assert_operator response.body.bytesize, :>, 200
    assert_includes response.body, "RecordingStudio Artifacts"
    assert_includes response.body, "Artifacts is on"
    assert_includes response.body, "MemoryStorage"
  end
end
