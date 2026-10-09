# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# RecordingStudioApi admin HTML requires host RootSwitchable + AdminRoot wiring.
# Without current_root_recording (AdminRoot), AdminController raises NameError.
class AdminApiPagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TEST_PASSWORD = "AdminApiPagesPassword!2026"

  ADMIN_API_PATHS = %w[
    /recording_studio_api/admin_api
    /recording_studio_api/admin_api/settings
    /recording_studio_api/admin_api/rate_limiting
    /recording_studio_api/admin_api/requests
    /recording_studio_api/admin_api/errors
    /recording_studio_api/admin_api/logs
  ].freeze

  setup do
    @user = User.create!(email: "admin-api-pages-#{SecureRandom.hex(4)}@example.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end

    # Own AdminRoot so bootstrap stays available even when seeds already own "Admin".
    @admin_root = AdminRoot.create!(name: "Admin API Pages #{SecureRandom.hex(3)}")
    @admin_root_recording = RecordingStudio::Recording.unscoped.create!(
      recordable: @admin_root,
      parent_recording_id: nil
    )

    result = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: @admin_root_recording,
      actor: @user
    )
    raise result.error unless result.success?

    RecordingStudioApi::Admin::ApiAuthorization.recording_for(
      api: :public,
      root_recording: @admin_root_recording,
      create: true
    )

    sign_in @user
  end

  test "signed-in admin gets 200 from every admin_api HTML page" do
    assert defined?(RecordingStudio::RootSwitchable::ControllerSupport)
    assert_includes RecordingStudioApi::ApplicationController.included_modules,
                    RecordingStudio::RootSwitchable::ControllerSupport

    ADMIN_API_PATHS.each do |path|
      get path
      assert_response :success, "#{path} expected 200, got #{response.status}: #{response.body.to_s[0, 240]}"
      assert_includes response.media_type.to_s, "text/html"
      refute_match(/NameError|current_root_recording/, response.body)
    end
  end
end
