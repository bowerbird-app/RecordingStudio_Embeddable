# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class PublishableAccessSeedTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  TEST_PASSWORD = "Password123!"

  setup do
    @user = User.create!(
      email: "publishable-seed-#{SecureRandom.hex(4)}@example.com",
      password: TEST_PASSWORD,
      password_confirmation: TEST_PASSWORD
    )
    workspace = Workspace.create!(name: "Publishable Seed Workspace #{SecureRandom.hex(3)}")
    @root = RecordingStudio::Recording.unscoped.create!(recordable: workspace, parent_recording_id: nil)
    folder = Folder.create!(name: "Docs")
    folder_recording = RecordingStudio::Recording.unscoped.create!(
      root_recording_id: @root.id,
      parent_recording_id: @root.id,
      recordable: folder
    )
    page = Page.create!(title: "Seed Publish Page")
    @page_recording = RecordingStudio::Recording.unscoped.create!(
      root_recording_id: @root.id,
      parent_recording_id: folder_recording.id,
      recordable: page
    )
    RecordingStudioPublishable::Services::Publishables::EnsureChild.call(
      parent_recording: @page_recording,
      actor: @user
    )
  end

  test "bootstrap owner access unlocks publishable edit and preview" do
    refute RecordingStudioAccessible.authorized?(
      actor: @user,
      recording: @page_recording,
      role: :edit
    )

    bootstrap = RecordingStudioAccessible.bootstrap_owner_access!(
      recording: @root,
      actor: @user
    )
    assert bootstrap.success?, bootstrap.error.to_s

    assert RecordingStudioAccessible.authorized?(
      actor: @user,
      recording: @page_recording,
      role: :edit
    )
    assert RecordingStudioPublishable.configuration.authorize_management?(
      recording: @page_recording,
      actor: @user
    )
    assert RecordingStudioPublishable.configuration.authorize_preview?(
      recording: @page_recording,
      actor: @user
    )

    sign_in @user

    get "/recordings/#{@page_recording.id}/publishable/edit"
    assert_response :success
    assert_includes response.body, "Publish"

    get "/recordings/#{@page_recording.id}/publishable/preview"
    assert_response :success
    assert_operator response.body.bytesize, :>, 200
  end

  test "grant_access alone cannot create the first admin on an empty root" do
    result = RecordingStudioAccessible.grant_access(
      recording: @root,
      actor: @user,
      role: :admin
    )

    refute result.success?
    assert_match(/not authorized/i, result.error.to_s)
  end

  test "seeds file bootstraps owner access before viewer grants" do
    seeds = File.read(Rails.root.join("db/seeds.rb"))

    assert_includes seeds, "bootstrap_owner_access!"
    assert_includes seeds, "manager_actor: user"
    refute_match(
      /grant_access\(recording: root_recording, actor: user, role: :admin\)/,
      seeds
    )
  end
end
